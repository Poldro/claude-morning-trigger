# claude-morning-trigger

A tiny macOS [launchd](https://www.launchd.info/) job that runs `claude -p "<prompt>"` every morning at a fixed time.

Why? Triggering a short Claude Code session early in the day starts your 5 hours token session so that you can 3 sessions instead of 3 during work day.

This repo ships:

- `claude-morning-trigger.plist.template` — the LaunchAgent template
- `install.sh` — renders the template, drops it in `~/Library/LaunchAgents/`, and loads it via `launchctl bootstrap`
- `uninstall.sh` — symmetric removal

## Prerequisites

- macOS (uses `launchd`)
- [Claude Code](https://docs.claude.com/claude-code) installed and the `claude` binary available in your login `PATH` (the job runs under `zsh -l`, so anything sourced from your shell rc files is visible)

## Quick start

```bash
git clone https://github.com/Poldro/claude-morning-trigger.git
cd claude-morning-trigger
chmod +x install.sh uninstall.sh
./install.sh
```

That installs a job under the label `com.<your-user>.claude-default-morning-trigger` that fires daily at **06:00** and runs `claude -p "ping"`.

## Multiple profiles

If you keep separate Claude configs (e.g. work vs personal), install one job per profile and point each at a different `CLAUDE_CONFIG_DIR`:

```bash
# work profile, 06:00, uses ~/.claude-work
CLAUDE_CONFIG_DIR="$HOME/.claude-work" ./install.sh work

# personal profile, 07:30, uses ~/.claude-personal
CLAUDE_HOUR=7 CLAUDE_MINUTE=30 \
  CLAUDE_CONFIG_DIR="$HOME/.claude-personal" \
  ./install.sh personal
```

Each profile gets its own plist, its own launchd label, and its own log dir.

## Configuration

All settings are env vars consumed by `install.sh`. Defaults in parentheses.

| Variable | Default | Description |
| --- | --- | --- |
| `CLAUDE_HOUR` | `6` | Hour of day (0–23) |
| `CLAUDE_MINUTE` | `0` | Minute of hour (0–59) |
| `CLAUDE_PROMPT` | `ping` | Prompt passed to `claude -p` |
| `CLAUDE_CONFIG_DIR` | _(unset)_ | Absolute path to a Claude config dir; exported into the job's environment. Omit if you only have `~/.claude`. |
| `CLAUDE_LOG_DIR` | `$CLAUDE_CONFIG_DIR/logs` or `$HOME/.claude/logs` | Where stdout/stderr go |
| `LABEL_PREFIX` | `com.<your-user>` | Reverse-DNS prefix for the launchd Label |

## Verify it's loaded

```bash
launchctl list | grep claude-
launchctl print "gui/$(id -u)/com.$(whoami).claude-default-morning-trigger" | head
```

## Trigger it manually (without waiting for the scheduled time)

```bash
launchctl kickstart -k "gui/$(id -u)/com.$(whoami).claude-default-morning-trigger"
tail -f ~/.claude/logs/morning-trigger.out.log
```

## Uninstall

```bash
./uninstall.sh            # removes the "default" profile
./uninstall.sh work       # removes the "work" profile
```

## Caveats

- **`RunAtLoad` is `false`.** If your Mac is asleep or off at the scheduled time, launchd will fire the job as soon as the system wakes — but if it's fully shut down, the missed run is **not** retried. If you need guaranteed daily execution, run it on a server or schedule multiple times of day.
- **The `claude` CLI must be on your login `PATH`.** The job runs under `/bin/zsh -l -c`, so it sources `~/.zprofile` / `~/.zshrc`. If `claude` is installed via a node version manager or a path-conditional shim, double-check that it resolves from a non-interactive login shell: `zsh -l -c 'command -v claude'`.
- **Logs are not rotated.** They grow forever. Truncate or rotate manually if it bothers you.
- **No retry on failure.** If `claude` errors out, the next scheduled run is still tomorrow at the configured time.

## License

MIT
