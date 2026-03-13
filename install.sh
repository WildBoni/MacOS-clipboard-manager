#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="ClipboardManager"
APP_PATH="$HOME/Applications/${BINARY_NAME}.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/$BINARY_NAME"
UNINSTALLER_PATH="$HOME/Applications/${BINARY_NAME} Uninstaller.app"
PLIST_NAME="com.user.clipboardmanager.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

# Assembles a .app bundle, ad-hoc signs it, and makes the executable runnable.
# Usage: make_bundle <bundle_path> <binary_src> <binary_name> <plist_src>
make_bundle() {
    local bundle="$1" binary_src="$2" binary_name="$3" plist_src="$4"
    rm -rf "$bundle"
    mkdir -p "$bundle/Contents/MacOS"
    cp "$binary_src" "$bundle/Contents/MacOS/$binary_name"
    cp "$plist_src"  "$bundle/Contents/Info.plist"
    chmod 755 "$bundle/Contents/MacOS/$binary_name"
    codesign --force --deep --sign - "$bundle"
}

echo "→ Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

echo "→ Assembling app bundle at $APP_PATH ..."
make_bundle "$APP_PATH" \
    ".build/release/$BINARY_NAME"                  "$BINARY_NAME" \
    "Sources/ClipboardManager/Info.plist"

echo "→ Assembling uninstaller..."
make_bundle "$UNINSTALLER_PATH" \
    "Installer/uninstaller-app/uninstall"          "uninstall" \
    "Installer/uninstaller-app/Info.plist"

echo "→ Installing LaunchAgent..."
LOG_DIR="$HOME/Library/Logs/ClipboardManager"
mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
sed -e "s|BINARY_PATH|$BINARY_PATH|g" \
    -e "s|LOG_DIR|$LOG_DIR|g" \
    "$SCRIPT_DIR/LaunchAgent/$PLIST_NAME" > "$PLIST_DEST"
# Restrict the plist to owner-read/write only.
chmod 600 "$PLIST_DEST"

echo "→ Loading LaunchAgent (stopping old instance first if present)..."
# load/unload are deprecated since macOS 10.11; use bootstrap/bootout instead.
launchctl bootout "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"

echo ""
echo "✓  ClipboardManager installed and running!"
echo ""
echo "   Hotkey : Cmd+Shift+V"
echo "   Nav    : ↑↓ arrows, 1–5 quick pick, ↵ select, ⎋ close"
echo ""
echo "   Uninstall: open ~/Applications/ClipboardManager\ Uninstaller.app"
