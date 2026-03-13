#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="ClipboardManager"
IDENTIFIER="com.user.clipboardmanager"
VERSION="1.0"

STAGING_DIR="$SCRIPT_DIR/.pkg-staging"
COMPONENT_PKG="$SCRIPT_DIR/$BINARY_NAME.pkg"
INSTALLER_PKG="$SCRIPT_DIR/${BINARY_NAME}-Installer.pkg"

# Clean up intermediate artifacts on exit (success or failure).
trap 'rm -rf "$STAGING_DIR" "$COMPONENT_PKG"' EXIT

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

for tool in pkgbuild productbuild; do
    command -v "$tool" > /dev/null 2>&1 || {
        echo "Error: '$tool' not found. Install Xcode Command Line Tools first:"
        echo "  xcode-select --install"
        exit 1
    }
done

echo "→ Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release

echo "→ Staging payload..."
rm -rf "$STAGING_DIR"
make_bundle "$STAGING_DIR/Applications/$BINARY_NAME.app" \
    ".build/release/$BINARY_NAME"                  "$BINARY_NAME" \
    "Sources/ClipboardManager/Info.plist"

make_bundle "$STAGING_DIR/Applications/$BINARY_NAME Uninstaller.app" \
    "Installer/uninstaller-app/uninstall"          "uninstall" \
    "Installer/uninstaller-app/Info.plist"

echo "→ Building component package..."
pkgbuild \
    --root "$STAGING_DIR" \
    --scripts "$SCRIPT_DIR/Installer/scripts" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"

echo "→ Building installer package..."
productbuild \
    --distribution "$SCRIPT_DIR/Installer/distribution.xml" \
    --resources "$SCRIPT_DIR/Installer/resources" \
    --package-path "$SCRIPT_DIR" \
    "$INSTALLER_PKG"

echo ""
echo "✓  Installer ready: $INSTALLER_PKG"
echo "   Double-click to install ClipboardManager."
