#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="ClipboardManager"
FOLDER_PATH="$HOME/Applications/$BINARY_NAME"
APP_PATH="$FOLDER_PATH/${BINARY_NAME}.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/$BINARY_NAME"
UNINSTALLER_PATH="$FOLDER_PATH/Uninstall ${BINARY_NAME}.app"
PLIST_NAME="com.user.clipboardmanager.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

# shellcheck source=scripts/make_bundle.sh
source "$SCRIPT_DIR/scripts/make_bundle.sh"

echo "→ Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

echo "→ Removing legacy app locations (if any)..."
rm -rf "$HOME/Applications/${BINARY_NAME}.app"
rm -rf "$HOME/Applications/${BINARY_NAME} Uninstaller.app"

echo "→ Assembling app bundle at $APP_PATH ..."
mkdir -p "$FOLDER_PATH"
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
# Use PlistBuddy to write the plist safely — avoids sed delimiter/metacharacter issues.
cp "$SCRIPT_DIR/LaunchAgent/$PLIST_NAME" "$PLIST_DEST"
/usr/libexec/PlistBuddy -c "Set :ProgramArguments:0 $BINARY_PATH"       "$PLIST_DEST"
/usr/libexec/PlistBuddy -c "Set :StandardOutPath $LOG_DIR/ClipboardManager.log" "$PLIST_DEST"
/usr/libexec/PlistBuddy -c "Set :StandardErrorPath $LOG_DIR/ClipboardManager.log" "$PLIST_DEST"
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
echo "   Uninstall: open ~/Applications/ClipboardManager/Uninstall\ ClipboardManager.app"
