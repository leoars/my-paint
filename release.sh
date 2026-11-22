#!/bin/bash
# Builds the two installers signed with Developer ID, has Apple notarize them and staples the
# tickets. Usage: ./release.sh
#
# Needs, on this Mac:
#   - the "Developer ID Application" and "Developer ID Installer" identities in the keychain;
#   - a notarytool profile, created once with
#       xcrun notarytool store-credentials "my-suite-notary" --team-id <team>
# Set NOTARY_PROFILE, DEVELOPER_ID_APPLICATION or DEVELOPER_ID_INSTALLER to override the defaults.
set -euo pipefail
cd "$(dirname "$0")"
profile="${NOTARY_PROFILE:-my-suite-notary}"

identity() {
    security find-identity -v | sed -n "s/.*\"\\($1: [^\"]*\\)\".*/\\1/p" | head -1
}
application="${DEVELOPER_ID_APPLICATION:-$(identity 'Developer ID Application')}"
installer="${DEVELOPER_ID_INSTALLER:-$(identity 'Developer ID Installer')}"
if [[ -z "$application" || -z "$installer" ]]; then
    echo "Missing signing identity in the keychain:" >&2
    [[ -n "$application" ]] || echo "  Developer ID Application" >&2
    [[ -n "$installer" ]] || echo "  Developer ID Installer" >&2
    exit 1
fi
if ! xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
    echo "The notarytool profile \"$profile\" is missing or no longer valid." >&2
    exit 1
fi

DEVELOPER_ID_APPLICATION="$application" DEVELOPER_ID_INSTALLER="$installer" ./package.sh

version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
for arch in arm64 x86_64; do
    package="dist/My-Paint-$version-$arch.pkg"
    xcrun notarytool submit "$package" --keychain-profile "$profile" --wait
    xcrun stapler staple "$package"
    xcrun stapler validate "$package"
    # Gatekeeper's own verdict on the stapled installer.
    spctl --assess --type install --verbose "$package"
    shasum -a 256 "$package"
done
