#!/usr/bin/env bash
# Install a macOS launchd job that runs `claude -p <prompt>` every morning.
#
# Usage:
#   ./install.sh [profile]
#
# Profile is an arbitrary short name (e.g. "work", "personal", "default").
# It is used only to build the launchd Label and the plist filename so you
# can install multiple jobs side by side.
#
# Configuration (env vars, all optional):
#   CLAUDE_HOUR         hour of day, 0-23                       (default: 6)
#   CLAUDE_MINUTE       minute of hour, 0-59                    (default: 0)
#   CLAUDE_PROMPT       prompt sent via `claude -p`             (default: ping)
#   CLAUDE_CONFIG_DIR   absolute path to a Claude config dir;
#                       if set, exported to the job's env       (default: unset)
#   CLAUDE_LOG_DIR      where to write stdout/stderr logs       (default:
#                       $CLAUDE_CONFIG_DIR/logs if set,
#                       else $HOME/.claude/logs)
#   LABEL_PREFIX        reverse-DNS prefix for the launchd Label
#                                                               (default: com.<user>)
#
# Examples:
#   ./install.sh                                  # default profile, 06:00, prompt "ping"
#   CLAUDE_HOUR=7 ./install.sh work               # work profile, 07:00
#   CLAUDE_CONFIG_DIR=$HOME/.claude-work \
#     CLAUDE_PROMPT="daily standup" \
#     ./install.sh work

set -euo pipefail

PROFILE="${1:-default}"
HOUR="${CLAUDE_HOUR:-6}"
MINUTE="${CLAUDE_MINUTE:-0}"
PROMPT="${CLAUDE_PROMPT:-ping}"
CLAUDE_CONFIG_DIR_VAL="${CLAUDE_CONFIG_DIR:-}"
LABEL_PREFIX="${LABEL_PREFIX:-com.$(whoami)}"

LABEL="${LABEL_PREFIX}.claude-${PROFILE}-morning-trigger"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [[ -n "$CLAUDE_CONFIG_DIR_VAL" ]]; then
  LOG_DIR="${CLAUDE_LOG_DIR:-${CLAUDE_CONFIG_DIR_VAL}/logs}"
else
  LOG_DIR="${CLAUDE_LOG_DIR:-${HOME}/.claude/logs}"
fi

# --- preflight ---
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' CLI not found in PATH." >&2
  echo "Install Claude Code first: https://docs.claude.com/claude-code" >&2
  exit 1
fi

if ! [[ "$HOUR" =~ ^[0-9]+$ ]] || (( HOUR < 0 || HOUR > 23 )); then
  echo "Error: CLAUDE_HOUR must be 0-23 (got: $HOUR)" >&2
  exit 1
fi
if ! [[ "$MINUTE" =~ ^[0-9]+$ ]] || (( MINUTE < 0 || MINUTE > 59 )); then
  echo "Error: CLAUDE_MINUTE must be 0-59 (got: $MINUTE)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/claude-morning-trigger.plist.template"
if [[ ! -f "$TEMPLATE" ]]; then
  echo "Error: template not found at $TEMPLATE" >&2
  exit 1
fi

# --- build env block (multiline, may be empty) ---
ENV_BLOCK=""
if [[ -n "$CLAUDE_CONFIG_DIR_VAL" ]]; then
  ENV_BLOCK=$'\n    <key>EnvironmentVariables</key>\n    <dict>\n        <key>CLAUDE_CONFIG_DIR</key>\n        <string>'"${CLAUDE_CONFIG_DIR_VAL}"$'</string>\n    </dict>\n'
fi

# escape prompt for embedding inside double-quoted shell command
ESCAPED_PROMPT=${PROMPT//\\/\\\\}
ESCAPED_PROMPT=${ESCAPED_PROMPT//\"/\\\"}
COMMAND="claude -p \"${ESCAPED_PROMPT}\""

mkdir -p "$LOG_DIR"
mkdir -p "${HOME}/Library/LaunchAgents"

# --- render plist via bash string substitution (handles multi-line env block) ---
RENDERED="$(<"$TEMPLATE")"
RENDERED="${RENDERED//__LABEL__/$LABEL}"
RENDERED="${RENDERED//__COMMAND__/$COMMAND}"
RENDERED="${RENDERED//__HOUR__/$HOUR}"
RENDERED="${RENDERED//__MINUTE__/$MINUTE}"
RENDERED="${RENDERED//__LOG_DIR__/$LOG_DIR}"
RENDERED="${RENDERED//__ENV_BLOCK__/$ENV_BLOCK}"
printf '%s\n' "$RENDERED" > "$PLIST_PATH"

# --- (re)load via launchctl ---
DOMAIN="gui/$(id -u)"

if launchctl print "${DOMAIN}/${LABEL}" >/dev/null 2>&1; then
  echo "Unloading existing job ${LABEL}..."
  launchctl bootout "${DOMAIN}/${LABEL}" || true
fi

echo "Loading ${LABEL}..."
launchctl bootstrap "${DOMAIN}" "${PLIST_PATH}"

cat <<EOF

Installed: ${PLIST_PATH}
Label:     ${LABEL}
Schedule:  daily at $(printf '%02d:%02d' "$HOUR" "$MINUTE")
Prompt:    ${PROMPT}
Logs:      ${LOG_DIR}/morning-trigger.{out,err}.log
$(if [[ -n "$CLAUDE_CONFIG_DIR_VAL" ]]; then echo "Config:    CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR_VAL}"; fi)

Verify with:  launchctl print ${DOMAIN}/${LABEL} | head
Trigger now:  launchctl kickstart -k ${DOMAIN}/${LABEL}
Uninstall:    ./uninstall.sh ${PROFILE}
EOF
