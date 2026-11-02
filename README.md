# codex-intel-rebuilder

Re-package the official **Codex desktop app** (OpenAI) to run on **Intel Macs**.

OpenAI ships the Codex desktop app as an **Apple Silicon (arm64) only** build, so
on an Intel Mac it won't launch. This repo is a single build script that
re-assembles the app around an **x64 Electron runtime**, rebuilds its native
modules for Intel, and drops in the x64 `codex` binary you already have from the
npm CLI.

It runs entirely on your machine on a copy of the app **you** download. It
**does not contain or redistribute any OpenAI code** — the script extracts the
app logic from your own official `Codex.dmg` at build time. It accepts both the
new `ChatGPT.app` bundle and the older `Codex.app` bundle.

> ⚠️ **Unofficial.** Not affiliated with, supported by, or endorsed by OpenAI.
> The Intel bundle is unsigned and locally rebuilt. OpenAI ships the source app
> for Apple Silicon; this project rebuilds it for Intel on your Mac.

---

## How it works

`rebuild_codex.js`:

1. Mounts your official DMG and extracts the app logic (`app.asar`), icon, and
   source metadata.
2. Downloads the **darwin-x64** Electron runtime from official Electron GitHub
   releases. The rebuilt bundle keeps Electron's launcher metadata and uses the
   source app's version and identifier.
3. Rebuilds the native modules (`better-sqlite3`, `node-pty`) for Electron x64,
   preferring prebuilt binaries and falling back to a C++20 source build.
4. Copies the **x64 `codex`** (and `rg`/ripgrep) binary out of your global
   `@openai/codex` install.
5. Wraps the launcher so the app starts with `--no-sandbox` and a PATH that can
   see your nvm/Homebrew/pnpm globals.
6. Copies the x64 `codex-code-mode-host` when available and produces
   `Codex_Intel.app`.

## Requirements

- An **Intel Mac** (the whole point).
- **Node.js** on your PATH.
- **Xcode Command Line Tools** (`xcode-select --install`) — Xcode 15+ recommended
  so the C++20 native-module fallback can compile if no prebuilt is available.
- The official **Codex CLI** installed globally (provides the x64 binary):
  ```bash
  npm install -g @openai/codex
  ```
- The official **`Codex.dmg`** (Apple Silicon installer) from OpenAI, placed in this
  folder. Download it from OpenAI's official distribution.

## Build

```bash
git clone https://github.com/Szpili/codex-intel-rebuilder.git
cd codex-intel-rebuilder
# put Codex.dmg here, then:
node rebuild_codex.js
```

Fully clean build (clears cached resources + Electron zip):

```bash
node rebuild_codex.js --clean
```

## Run

```bash
open Codex_Intel.app
```

If macOS says the app is "damaged" or "Operation not permitted", clear the
quarantine attribute (the app is self-signed/unsigned):

```bash
xattr -cr Codex_Intel.app
```

## Updating

The optional local updater checks OpenAI's appcast at login and every 24 hours,
and updates the global Codex CLI from npm. If the app or bundled CLI is out of
date, it downloads the official DMG, verifies the disk image, rebuilds the Intel
app locally, and replaces the installed copy. If Codex is open, it defers the
app replacement until the next check. Install it with:

```bash
bash scripts/install-auto-updater.sh
```

Updater output is written to `~/Library/Logs/codex-intel-updater.log`. Remove
`~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist` and boot it out
with `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist`
to disable automatic updates.

To rebuild manually, replace `Codex.dmg` with the new official installer and run
`node rebuild_codex.js --clean`. The installed app is kept until you move the
newly built app into `~/Applications`.

## Security note (`--no-sandbox`)

The built app launches with Electron's `--no-sandbox` flag via a wrapper at
`Contents/MacOS/Codex`. This disables Chromium's internal process sandbox, which
is what lets tools like Playwright spawn browser subprocesses from the integrated
terminal. It is **separate** from the macOS Seatbelt sandbox Codex uses for
workspace isolation. To allow network access inside the Codex terminal, set in
your Codex `config.toml`:

```toml
[sandbox_workspace_write]
network_access = true
```

## Troubleshooting

- **"Operation not permitted" / "damaged"** — `xattr -cr Codex_Intel.app`.
- **Native-module build errors** (`source_location`, C++ errors) — update Xcode
  CLT (`xcode-select --install`); the script forces `-std=c++20` for Electron 40.
- **"Could not find local x64 Codex binary"** — ensure `@openai/codex` is
  installed globally; check `npm list -g @openai/codex`.
- **App aborts during launch** — the rebuilder keeps Electron's
  `NSPrincipalClass` (`AtomApplication`). The source app's custom
  `BrowserCrApplication` class is not present in stock Electron.
- **Code Mode unavailable** — update the global Codex CLI and rebuild so the
  x64 `codex-code-mode-host` is copied alongside the CLI binary.

## License

MIT (original build script + docs only). See [LICENSE](LICENSE). Not affiliated
with OpenAI.

---

<a name="polski"></a>

# 🇵🇱 Wersja polska

Przepakowuje oficjalną **apkę desktopową Codex** (OpenAI) tak, by działała na
**Makach z Intelem**.

OpenAI wydaje Codex desktop **tylko na Apple Silicon (arm64)**, więc na Intelu nie
odpala się w ogóle. To repo to jeden skrypt, który składa apkę na nowo wokół
**Electrona x64**, przebudowuje jej moduły natywne pod Intela i podstawia binarkę
`codex` x64, którą i tak masz z CLI z npm.

Działa **w całości lokalnie**, na kopii apki, którą pobierasz **sam**. **Nie
zawiera ani nie rozpowszechnia kodu OpenAI** — skrypt wyciąga logikę aplikacji z
oficjalnego `Codex.dmg`. Obsługuje nowe `ChatGPT.app` i starsze `Codex.app`.

> ⚠️ **Nieoficjalne.** Brak powiązania z OpenAI, bez ich wsparcia. Wersja Intel
> jest składana lokalnie i nie jest podpisana przez OpenAI.

## Wymagania

- **Mac z Intelem**.
- **Node.js** na PATH.
- **Xcode Command Line Tools** (`xcode-select --install`).
- Globalny **Codex CLI**: `npm install -g @openai/codex` (daje binarkę x64).
- Oficjalny **`Codex.dmg`** od OpenAI, wrzucony do tego katalogu.

## Budowanie

```bash
git clone https://github.com/Szpili/codex-intel-rebuilder.git
cd codex-intel-rebuilder
# wrzuć tu Codex.dmg, potem:
node rebuild_codex.js            # albo: node rebuild_codex.js --clean
open Codex_Intel.app
```

Jeśli macOS twierdzi, że apka jest „uszkodzona": `xattr -cr Codex_Intel.app`.

## Aktualizacja

Opcjonalny updater sprawdza appcast OpenAI przy logowaniu i co 24 godziny. Gdy
pojawi się nowa wersja, pobiera oficjalny DMG, weryfikuje obraz, lokalnie buduje
wersję Intel i podmienia zainstalowaną apkę. Aktualizuje też globalny Codex CLI
przez npm.

```bash
bash scripts/install-auto-updater.sh
```

Jeśli Codex jest uruchomiony, podmiana apki poczeka do kolejnego sprawdzenia.
Log znajduje się w
`~/Library/Logs/codex-intel-updater.log`. Aby wyłączyć updater, usuń
`~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist` i wykonaj
`launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.szpili.codex-intel-updater.plist`.

## Licencja

MIT (tylko skrypt + dokumentacja). Patrz [LICENSE](LICENSE). Bez powiązania z OpenAI.
