# ClipboardManager

A minimal, native macOS clipboard history manager. No Electron, no dependencies — just a small Swift binary (~2 MB) that runs quietly in the background.

## Requirements

- macOS 14 Sonoma or later

## How it works

ClipboardManager runs as a background process with no dock icon. Every time you copy text, it silently adds it to an in-memory history list (up to 50 items).

Press **⌘ Shift V** anywhere to open the history panel. Pick an item — it lands on your clipboard. Press **⌘ V** to paste as usual.

```
┌─────────────────────────────────────────┐
│           Clipboard History             │
├─────────────────────────────────────────┤
│  1  the quick brown fox                 │
│  2  hello@example.com                   │
│  3  https://github.com/...              │
│  4  Some longer text that was copied…   │
│  5  another snippet                     │
│     ...                                 │
└─────────────────────────────────────────┘
  ↑↓ navigate  1–5 quick pick  ↵ select  ⎋ close
```

The panel adapts to light and dark mode automatically. Clicking anywhere outside the panel closes it.

## Hotkeys

| Key | Action |
|-----|--------|
| `⌘ Shift V` | Open / close the history panel |
| `↑` `↓` | Navigate the list |
| `1` – `5` | Jump directly to items 1–5 |
| `↵` | Copy selected item to clipboard and close |
| `⎋` | Close without selecting |

Double-clicking an item works too.

## Install

### Option A — visual installer (recommended)

```bash
bash build-installer.sh
```

This produces `ClipboardManager-Installer.pkg`. Double-click it to run the macOS installer wizard. It will install `ClipboardManager.app` to `/Applications`, register a LaunchAgent, and start the app automatically.

Requires Xcode Command Line Tools (`xcode-select --install`).

> **Gatekeeper note:** If macOS warns the app can't be verified, right-click the `.pkg` and choose Open. The installer uses ad-hoc code signing, which should prevent this in most cases.

### Option B — manual install

```bash
bash install.sh
```

Builds a release binary, assembles `~/Applications/ClipboardManager.app`, and registers a LaunchAgent so the app starts automatically at login.

## Uninstall

Double-click **ClipboardManager Uninstaller.app** (installed alongside the app in the same folder). It will ask for confirmation, stop the background process, and remove all files.

If you prefer the command line:

```bash
bash uninstall.sh
```

Pass `--yes` to skip the confirmation prompt.

## Notes

- History is **in-memory only** — nothing is written to disk.
- **Passwords are never stored.** Items copied from password managers (1Password, Keychain, etc.) are automatically skipped via the [nspasteboard.org](http://nspasteboard.org) protocol.
- Only plain text is tracked. Images, files, and other clipboard types are ignored.
- Items larger than 100 KB are silently dropped to avoid memory spikes.
