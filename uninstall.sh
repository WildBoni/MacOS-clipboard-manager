#!/bin/bash
set -euo pipefail

BINARY_NAME="ClipboardManager"
LABEL="com.user.clipboardmanager"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/ClipboardManager"
APP_USER="$HOME/Applications/ClipboardManager.app"
APP_SYSTEM="/Applications/ClipboardManager.app"
BIN_USER="$HOME/bin/$BINARY_NAME"        # legacy fallback
BIN_SYSTEM="/usr/local/bin/$BINARY_NAME" # legacy fallback

# Parse flags
CONFIRM=true
for arg in "$@"; do
    case "$arg" in
        --yes|-y) CONFIRM=false ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

# Detect what's installed
INSTALLED_APP=""
[ -d "$APP_USER" ]   && INSTALLED_APP="$APP_USER"
[ -d "$APP_SYSTEM" ] && INSTALLED_APP="$APP_SYSTEM"
INSTALLED_BINARY=""
[ -f "$BIN_USER" ]   && INSTALLED_BINARY="$BIN_USER"
[ -f "$BIN_SYSTEM" ] && INSTALLED_BINARY="$BIN_SYSTEM"

PLIST_FOUND=false; [ -f "$PLIST_PATH" ] && PLIST_FOUND=true
LOGS_FOUND=false;  [ -d "$LOG_DIR"    ] && LOGS_FOUND=true

if [ -z "$INSTALLED_APP" ] && [ -z "$INSTALLED_BINARY" ] && \
   [ "$PLIST_FOUND" = false ] && [ "$LOGS_FOUND" = false ]; then
    echo "ClipboardManager does not appear to be installed. Nothing to remove."
    exit 0
fi

# Show what will be removed
echo ""
echo "The following will be removed:"
[ -n "$INSTALLED_APP"    ] && echo "  App    : $INSTALLED_APP"
[ -n "$INSTALLED_BINARY" ] && echo "  Binary : $INSTALLED_BINARY (legacy)"
[ "$PLIST_FOUND" = true ] && echo "  Plist  : $PLIST_PATH"
[ "$LOGS_FOUND"  = true ] && echo "  Logs   : $LOG_DIR"
echo ""

if [ "$CONFIRM" = true ]; then
    read -r -p "Proceed? [y/N] " reply
    case "$reply" in
        [Yy]*) ;;
        *) echo "Aborted."; exit 0 ;;
    esac
fi

echo ""
echo "→ Stopping LaunchAgent..."
if launchctl list "$LABEL" > /dev/null 2>&1; then
    launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || true
    echo "  Stopped."
else
    echo "  Not running (skipped)."
fi

echo "→ Removing app bundle..."
if [ -n "$INSTALLED_APP" ]; then
    rm -rf "$INSTALLED_APP"
    echo "  Removed: $INSTALLED_APP"
elif [ -n "$INSTALLED_BINARY" ]; then
    rm -f "$INSTALLED_BINARY"
    echo "  Removed: $INSTALLED_BINARY"
else
    echo "  Not found (skipped)."
fi

echo "→ Removing LaunchAgent plist..."
if [ "$PLIST_FOUND" = true ]; then
    rm -f "$PLIST_PATH"
    echo "  Removed: $PLIST_PATH"
else
    echo "  Not found (skipped)."
fi

echo "→ Removing logs..."
if [ "$LOGS_FOUND" = true ]; then
    rm -rf "$LOG_DIR"
    echo "  Removed: $LOG_DIR"
else
    echo "  Not found (skipped)."
fi

echo ""
echo "✓  ClipboardManager uninstalled."
