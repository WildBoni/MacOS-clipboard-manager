#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="ClipboardManager"
INSTALL_DIR="$HOME/bin"
BINARY_PATH="$INSTALL_DIR/$BINARY_NAME"
PLIST_NAME="com.user.clipboardmanager.plist"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "→ Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

echo "→ Installing binary to $BINARY_PATH ..."
mkdir -p "$INSTALL_DIR"
cp ".build/release/$BINARY_NAME" "$BINARY_PATH"
chmod +x "$BINARY_PATH"

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
echo "   To uninstall:"
echo "     launchctl bootout \"gui/\$(id -u)\" $PLIST_DEST"
echo "     rm $BINARY_PATH $PLIST_DEST"
echo "     rm -rf $HOME/Library/Logs/ClipboardManager"
