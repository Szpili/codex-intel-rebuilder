#!/bin/bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$HOME/Library/Logs"
exec >>"$HOME/Library/Logs/codex-intel-updater.log" 2>&1
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Checking signed Codex Intel release"
for node_bin in "$HOME"/.nvm/versions/node/*/bin; do
  if [ -d "$node_bin" ]; then PATH="$node_bin:$PATH"; fi
done
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
# Keep the terminal CLI independent; never modify the signed desktop bundle.
if [ "${1:-}" != "--dry-run" ] && command -v npm >/dev/null 2>&1; then
  npm update -g @openai/codex || echo "CLI update failed; continuing with desktop update."
fi
exec /usr/bin/python3 "$REPO_ROOT/scripts/update-native-codex.py" "$@"
