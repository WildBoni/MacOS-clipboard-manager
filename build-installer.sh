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
mkdir -p "$STAGING_DIR/usr/local/bin"
cp ".build/release/$BINARY_NAME" "$STAGING_DIR/usr/local/bin/$BINARY_NAME"
chmod 755 "$STAGING_DIR/usr/local/bin/$BINARY_NAME"

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
