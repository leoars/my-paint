#!/bin/bash
# Builds "My Paint.app" in the project root. Usage: ./build.sh [app path] [target triple]
set -eu
cd "$(dirname "$0")"
app="${1:-My Paint.app}"
bundle="$app/Contents"
flags=(-swift-version 5)
if [ "$#" -gt 1 ]; then flags+=(-target "$2"); fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$bundle/MacOS" "$bundle/Resources"
swiftc "${flags[@]}" -module-cache-path "$tmp/modules" -O Sources/*.swift -o "$tmp/MyPaint"
cp -R Resources/*.lproj "$bundle/Resources/"
# The icon is drawn by Tools/icon.swift; regenerate it there, not here.
cp Resources/MyPaint.icns LICENSE THIRD_PARTY_NOTICES.md "$bundle/Resources/"
cp Resources/Info.plist "$bundle/Info.plist"
cp "$tmp/MyPaint" "$bundle/MacOS/MyPaint"
swift -module-cache-path "$tmp/modules" Tools/FinderIcon.swift clear "$app"
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$app"
    codesign --verify --strict "$app"
else
    codesign --force --sign - "$app"
    # Keeps the free-form icon off the grey plate in Finder and the Dock (see Tools/FinderIcon.swift).
    swift -module-cache-path "$tmp/modules" Tools/FinderIcon.swift apply "$app"
fi
