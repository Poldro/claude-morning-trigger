#!/usr/bin/env bash
# Remove a launchd job previously installed with ./install.sh.
#
# Usage:
#   ./uninstall.sh [profile]
#
# Pass the same profile name and (if you customized it) LABEL_PREFIX you used
# during install.

set -euo pipefail

PROFILE="${1:-default}"
LABEL_PREFIX="${LABEL_PREFIX:-com.$(whoami)}"
LABEL="${LABEL_PREFIX}.claude-${PROFILE}-morning-trigger"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
DOMAIN="gui/$(id -u)"

if launchctl print "${DOMAIN}/${LABEL}" >/dev/null 2>&1; then
  echo "Unloading ${LABEL}..."
  launchctl bootout "${DOMAIN}/${LABEL}" || true
else
  echo "Job ${LABEL} is not currently loaded."
fi

if [[ -f "$PLIST_PATH" ]]; then
  rm -f "$PLIST_PATH"
  echo "Removed ${PLIST_PATH}"
else
  echo "No plist found at ${PLIST_PATH}"
fi
