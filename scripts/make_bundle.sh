#!/bin/bash
# Shared helper – source this file, do not execute it directly.
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
