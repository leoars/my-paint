#!/bin/bash
# Builds the Apple Silicon and Intel installers in dist/. Usage: ./package.sh
# Signs with DEVELOPER_ID_APPLICATION / DEVELOPER_ID_INSTALLER when both are set;
# otherwise the app is signed ad hoc and the installers are left unsigned.
set -euo pipefail
cd "$(dirname "$0")"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
minimum=12.0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p dist
signing=()
if [[ -n "${DEVELOPER_ID_APPLICATION:-}${DEVELOPER_ID_INSTALLER:-}" ]]; then
    : "${DEVELOPER_ID_APPLICATION:?Missing application signing identity}"
    : "${DEVELOPER_ID_INSTALLER:?Missing installer signing identity}"
    signing=(--sign "$DEVELOPER_ID_INSTALLER" --timestamp)
fi

for arch in arm64 x86_64; do
    work="$tmp/$arch"
    root="$work/root"
    app="$root/My Paint.app"
    mkdir -p "$root" "$work/scripts"
    ./build.sh "$app" "$arch-apple-macos$minimum"
    swift -module-cache-path "$work/modules" Tools/FinderIcon.swift clear "$app"
    # macOS puts free-form icons on a grey plate unless the app has a custom Finder icon, which
    # cannot be part of the signature, so the installer adds it once the app is in place.
    cat > "$work/scripts/postinstall" <<'SH'
#!/bin/bash
app="$2/My Paint.app"
/usr/bin/osascript -l JavaScript -e 'function run(argv) {
  ObjC.import("AppKit")
  const icon = $.NSImage.alloc.initWithContentsOfFile(argv[0] + "/Contents/Resources/MyPaint.icns")
  $.NSWorkspace.sharedWorkspace.setIconForFileOptions(icon, argv[0], 0)
}' "$app" || true
exit 0
SH
    chmod +x "$work/scripts/postinstall"
    pkgbuild --analyze --root "$root" "$work/components.plist"
    plutil -replace 0.BundleIsRelocatable -bool false "$work/components.plist"
    pkgbuild --root "$root" --component-plist "$work/components.plist" \
        --identifier local.mypaint.editor.pkg --version "$version" \
        --install-location /Applications --scripts "$work/scripts" "$work/Editor.pkg"

    cat > "$work/Distribution" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>My Paint</title>
  <options customize="never" hostArchitectures="$arch"/>
  <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
  <volume-check><allowed-os-versions><os-version min="$minimum"/></allowed-os-versions></volume-check>
  <choices-outline><line choice="editor"/></choices-outline>
  <choice id="editor" title="My Paint" visible="false"><pkg-ref id="local.mypaint.editor.pkg"/></choice>
  <pkg-ref id="local.mypaint.editor.pkg" version="$version">Editor.pkg</pkg-ref>
</installer-gui-script>
XML
    name="My-Paint-$version-$arch.pkg"
    productbuild ${signing[@]+"${signing[@]}"} --distribution "$work/Distribution" --package-path "$work" "$work/$name"

    # Check what the installer would put in /Applications, without installing it.
    pkgutil --expand-full "$work/$name" "$work/expanded"
    installed="$work/expanded/Editor.pkg/Payload/My Paint.app"
    test "$(lipo -archs "$installed/Contents/MacOS/MyPaint")" = "$arch"
    codesign --verify --strict "$installed"
    test -x "$work/expanded/Editor.pkg/Scripts/postinstall"
    cmp "$app/Contents/Resources/MyPaint.icns" "$installed/Contents/Resources/MyPaint.icns"
    if [[ -n "${DEVELOPER_ID_INSTALLER:-}" ]]; then
        codesign --verify --strict "$installed"
        pkgutil --check-signature "$work/$name"
    fi
    mv "$work/$name" "dist/$name"
done
