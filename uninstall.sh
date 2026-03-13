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
INSTALLED_APP_USER=""
INSTALLED_APP_SYSTEM=""
[ -d "$APP_USER" ]   && INSTALLED_APP_USER="$APP_USER"
[ -d "$APP_SYSTEM" ] && INSTALLED_APP_SYSTEM="$APP_SYSTEM"
INSTALLED_BINARY=""
[ -f "$BIN_USER" ]   && INSTALLED_BINARY="$BIN_USER"
[ -f "$BIN_SYSTEM" ] && INSTALLED_BINARY="$BIN_SYSTEM"

PLIST_FOUND=false; [ -f "$PLIST_PATH" ] && PLIST_FOUND=true
LOGS_FOUND=false;  [ -d "$LOG_DIR"    ] && LOGS_FOUND=true

if [ -z "$INSTALLED_APP_USER" ] && [ -z "$INSTALLED_APP_SYSTEM" ] && [ -z "$INSTALLED_BINARY" ] && \
   [ "$PLIST_FOUND" = false ] && [ "$LOGS_FOUND" = false ]; then
    echo "ClipboardManager does not appear to be installed. Nothing to remove."
    exit 0
fi

# Show what will be removed
echo ""
echo "The following will be removed:"
[ -n "$INSTALLED_APP_USER"   ] && echo "  App    : $INSTALLED_APP_USER"
[ -n "$INSTALLED_APP_SYSTEM" ] && echo "  App    : $INSTALLED_APP_SYSTEM"
[ -n "$INSTALLED_BINARY"     ] && echo "  Binary : $INSTALLED_BINARY (legacy)"
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

echo "→ Removing app bundle(s)..."
if [ -n "$INSTALLED_APP_USER" ] || [ -n "$INSTALLED_APP_SYSTEM" ]; then
    [ -n "$INSTALLED_APP_USER" ] && rm -rf "$INSTALLED_APP_USER" && echo "  Removed: $INSTALLED_APP_USER"
    if [ -n "$INSTALLED_APP_SYSTEM" ]; then
        if ! rm -rf "$INSTALLED_APP_SYSTEM" 2>/dev/null; then
            echo "  ERROR: Cannot remove $INSTALLED_APP_SYSTEM — re-run with sudo." >&2
            exit 1
        fi
        echo "  Removed: $INSTALLED_APP_SYSTEM"
    fi
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

echo "→ Removing Accessibility permission..."
tccutil reset Accessibility com.user.clipboardmanager 2>/dev/null && \
    echo "  Removed from Accessibility settings." || \
    echo "  Not found in Accessibility settings (skipped)."

echo ""
echo "✓  ClipboardManager uninstalled."
