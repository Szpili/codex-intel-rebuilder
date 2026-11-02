# Codex Intel updater

Download and install the unchanged Intel desktop archive from OpenAI's distribution
server on Intel Macs. Current desktop releases require OpenAI's Owl runtime;
replacing it with stock Electron fails during startup.

This is an independent updater, not an OpenAI project. The public appcast currently
advertises ARM64 releases only. An Intel archive is available at the corresponding
`ChatGPT-darwin-x64-<version>.zip` URL; future Intel availability is not guaranteed.
If that artifact is unavailable or fails validation, the installed app is retained.

## Install or update

Requires macOS, Python 3 (provided by Xcode Command Line Tools), and internet access.

```bash
python3 scripts/update-native-codex.py
open ~/Applications/Codex_Intel.app
```

The updater checks the official appcast for the release version, then downloads
the matching Intel archive over HTTPS. Before installation it verifies the bundle
identifier, release/build versions, x86_64 executable, full code signature with
OpenAI's Team ID `2DC432GLL2`, and Gatekeeper assessment. The signed bundle is not
modified, re-signed, or launched with `--no-sandbox`.

A running app is not replaced. The previous installation is kept at
`~/Applications/Codex_Intel.previous.app`, and a failed replacement is rolled back.
A process lock prevents overlapping updates. No account data or conversations are
removed.

```bash
# Check without downloading or replacing the application
python3 scripts/update-native-codex.py --dry-run

# Use an already downloaded archive (the same validation still applies)
python3 scripts/update-native-codex.py --archive ~/Downloads/ChatGPT-darwin-x64-26.1027.61615.zip

# Prepare a local bundle without replacing the installed application
node rebuild_codex.js
```

## Automatic updates

```bash
bash scripts/install-auto-updater.sh
```

A user LaunchAgent checks at login and every 24 hours. It also updates the separate
global `@openai/codex` CLI through npm when npm is available. Desktop updates use
the signed archive's bundled CLI and runtime together.

Logs: `~/Library/Logs/codex-intel-updater.log`.

To disable:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist
rm ~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist
```

## Legacy Electron rebuild

The old DMG extraction/native-module rebuild remains available explicitly:

```bash
node rebuild_codex.js --legacy-electron --clean
```

It requires a compatible older source DMG, npm Codex CLI, and native build tools.
It cannot run current Owl releases. Use the signed Intel archive for current
versions. The legacy bundle is unsigned and uses `--no-sandbox`.

## Po polsku

Najnowszy Codex wymaga własnego runtime OpenAI (Owl). Przebudowa na zwykłym
Electronie zatrzymuje start aplikacji. Domyślnie pobieramy teraz oryginalną paczkę
Intel z serwera OpenAI i sprawdzamy jej wersję, architekturę oraz podpis, bez
modyfikowania plików aplikacji.

Publiczny appcast wymienia obecnie tylko ARM64. Updater sprawdza odpowiadającą mu
paczkę x64; jeśli nie jest dostępna lub nie przejdzie weryfikacji, zachowuje
zainstalowaną aplikację. Nie gwarantuje to wsparcia Intela w przyszłych wydaniach.

Instalacja: `python3 scripts/update-native-codex.py`.
Automatyczne aktualizacje: `bash scripts/install-auto-updater.sh`.
Poprzednia instalacja zostaje jako `~/Applications/Codex_Intel.previous.app`.

## License

MIT. This repository contains only updater/rebuild scripts; no OpenAI application
code or binaries are redistributed.
