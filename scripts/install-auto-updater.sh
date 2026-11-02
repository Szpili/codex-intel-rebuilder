#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_ID="com.szpili.codex-intel-updater"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PATH="$AGENT_DIR/$AGENT_ID.plist"
LOG_DIR="$HOME/Library/Logs"

mkdir -p "$AGENT_DIR" "$LOG_DIR"
sed -e "s|@@REPO_ROOT@@|$REPO_ROOT|g" -e "s|@@HOME@@|$HOME|g" \
  "$REPO_ROOT/launchd/$AGENT_ID.plist.template" > "$AGENT_PATH"
plutil -lint "$AGENT_PATH"
launchctl bootout "gui/$(id -u)" "$AGENT_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PATH"
echo "Installed $AGENT_ID. It checks OpenAI's appcast at login and every 24 hours."
