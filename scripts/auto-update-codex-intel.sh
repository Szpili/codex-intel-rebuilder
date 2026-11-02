#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${CODEX_INTEL_APP_PATH:-$HOME/Applications/Codex_Intel.app}"
FEED_URL="https://persistent.oaistatic.com/codex-app-prod/appcast.xml"
DMG_URL="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
STATE_DIR="$HOME/Library/Application Support/Codex Intel Rebuilder"
LOG_FILE="$HOME/Library/Logs/codex-intel-updater.log"
DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; fi

for node_bin in "$HOME"/.nvm/versions/node/*/bin; do
  if [ -d "$node_bin" ]; then PATH="$node_bin:$PATH"; fi
done
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

mkdir -p "$STATE_DIR" "$HOME/Library/Logs"
exec >>"$LOG_FILE" 2>&1
echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Checking for Codex updates"

LATEST_BUILD="$(curl -fsSL "$FEED_URL" | /usr/bin/python3 -c '
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.stdin).getroot()
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
item = root.find("./channel/item")
value = item.findtext(sparkle + "version") if item is not None else None
if not value or not value.isdigit():
    raise SystemExit("Update feed did not contain a numeric build version")
print(value)
')"

CURRENT_BUILD=0
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
  CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo 0)"
fi
case "$CURRENT_BUILD" in (''|*[!0-9]*) CURRENT_BUILD=0 ;; esac
INSTALLED_CLI_VERSION="none"
if [ -x "$APP_PATH/Contents/Resources/codex" ]; then
  INSTALLED_CLI_VERSION="$("$APP_PATH/Contents/Resources/codex" --version 2>/dev/null | awk '/^codex-cli / { print $2; exit }')"
fi
GLOBAL_CLI_VERSION="$(codex --version 2>/dev/null | awk '/^codex-cli / { print $2; exit }' || true)"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Installed app build: $CURRENT_BUILD; latest: $LATEST_BUILD"
  echo "Bundled CLI: ${INSTALLED_CLI_VERSION:-unknown}; global CLI: ${GLOBAL_CLI_VERSION:-unknown}"
  if [ "$CURRENT_BUILD" -lt "$LATEST_BUILD" ] || [ "$INSTALLED_CLI_VERSION" != "$GLOBAL_CLI_VERSION" ]; then
    echo "Dry run: would rebuild and install the latest available app and CLI."
  else
    echo "Dry run: app and CLI are current."
  fi
  exit 0
fi

# Keep the bundled CLI current even when the desktop app release has not changed.
if command -v npm >/dev/null 2>&1; then
  if command -v codex >/dev/null 2>&1; then
    npm update -g @openai/codex || echo "Codex CLI update failed; continuing with the installed CLI."
  else
    npm install -g @openai/codex || echo "Codex CLI install failed; continuing with the installed CLI if available."
  fi
fi
GLOBAL_CLI_VERSION="$(codex --version 2>/dev/null | awk '/^codex-cli / { print $2; exit }' || true)"
echo "Installed app build: $CURRENT_BUILD; latest: $LATEST_BUILD"
echo "Bundled CLI: ${INSTALLED_CLI_VERSION:-unknown}; global CLI: ${GLOBAL_CLI_VERSION:-unknown}"
if [ "$CURRENT_BUILD" -ge "$LATEST_BUILD" ] && [ "$INSTALLED_CLI_VERSION" = "$GLOBAL_CLI_VERSION" ]; then
  echo "App and CLI are current."
  exit 0
fi

# Do not replace an app while it is running. The next daily check will retry.
if pgrep -f "$APP_PATH/Contents/MacOS/Codex.orig" >/dev/null 2>&1; then
  echo "Codex is open; deferring this update until the next check."
  exit 0
fi

DMG_PATH="$STATE_DIR/Codex.dmg"
TEMP_DMG="$STATE_DIR/Codex.dmg.download"
curl -fL --retry 3 "$DMG_URL" -o "$TEMP_DMG"
hdiutil verify "$TEMP_DMG"
mv "$TEMP_DMG" "$DMG_PATH"

MOUNT_POINT="$STATE_DIR/mount"
mkdir -p "$MOUNT_POINT"
mounted=0
cleanup() {
  if [ "$mounted" -eq 1 ]; then hdiutil detach "$MOUNT_POINT" -quiet || true; fi
  rm -f "$TEMP_DMG"
}
trap cleanup EXIT
hdiutil attach "$DMG_PATH" -nobrowse -readonly -mountpoint "$MOUNT_POINT" -quiet
mounted=1

SOURCE_APP="$MOUNT_POINT/ChatGPT.app"
if [ ! -d "$SOURCE_APP" ]; then SOURCE_APP="$MOUNT_POINT/Codex.app"; fi
if [ ! -f "$SOURCE_APP/Contents/Info.plist" ]; then
  echo "No ChatGPT.app or Codex.app found in official update image." >&2
  exit 1
fi
SOURCE_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_APP/Contents/Info.plist")"
if [ "$SOURCE_BUILD" != "$LATEST_BUILD" ]; then
  echo "Feed build $LATEST_BUILD does not match downloaded app build $SOURCE_BUILD." >&2
  exit 1
fi
hdiutil detach "$MOUNT_POINT" -quiet
mounted=0

CODEX_DMG_PATH="$DMG_PATH" node "$REPO_ROOT/rebuild_codex.js" --clean
BUILT_APP="$REPO_ROOT/Codex_Intel.app"
BUILT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUILT_APP/Contents/Info.plist")"
if [ "$BUILT_BUILD" != "$LATEST_BUILD" ]; then
  echo "Rebuilt app build $BUILT_BUILD does not match feed build $LATEST_BUILD." >&2
  exit 1
fi
xattr -cr "$BUILT_APP"

# Keep one rollback copy and make the replacement by same-volume rename.
BACKUP_PATH="$HOME/Applications/Codex_Intel.previous.app"
if [ -e "$APP_PATH" ]; then
  rm -rf "$BACKUP_PATH"
  mv "$APP_PATH" "$BACKUP_PATH"
fi
mkdir -p "$(dirname "$APP_PATH")"
if ! mv "$BUILT_APP" "$APP_PATH"; then
  if [ -e "$BACKUP_PATH" ]; then mv "$BACKUP_PATH" "$APP_PATH"; fi
  exit 1
fi
echo "Installed Codex Intel build $BUILT_BUILD. Previous app is at $BACKUP_PATH."
