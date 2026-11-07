#!/usr/bin/env bash
# Archives the iPhone app and uploads it to App Store Connect for TestFlight. Adapted from music-library.
# Needs Xcode 27, a paid Apple Developer Program team in Config/Local.xcconfig (DEVELOPMENT_TEAM) and the app's record
# in App Store Connect. Signing is automatic by default (the account in Xcode ▸ Settings ▸ Accounts).
#
#   VERSION=0.2.0        version (default: MARKETING_VERSION in Config/Version.xcconfig)
#   BUILD=202611071530   build number (default: the current UTC time, so every upload gets a new, higher one)
#   UPLOAD=0             export build/testflight/OneOrMany.ipa instead of uploading it
#   DEVELOPMENT_TEAM=…   the team, instead of Config/Local.xcconfig
#   ASC_KEY=path/to/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER=…
#                        sign in with an App Store Connect API key instead of the account in Xcode
#   DISTRIBUTION_CERTIFICATE=1
#                        sign manually with the Apple Distribution certificate in the keychain and an App Store profile
#                        made for it with the API key (scripts/provisioning-profiles.swift); for CI
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=OneOrMany.xcodeproj
SCHEME=OneOrMany
BUILD="${BUILD:-$(date -u +%Y%m%d%H%M)}"
ARCHIVE=build/OneOrMany.xcarchive
EXPORT=build/testflight

SETTINGS=(CURRENT_PROJECT_VERSION="$BUILD")
if [[ -n "${VERSION:-}" ]]; then SETTINGS+=(MARKETING_VERSION="$VERSION"); fi
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    SETTINGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
elif ! grep -qs '^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=' Config/Local.xcconfig; then
    echo "error: set DEVELOPMENT_TEAM in Config/Local.xcconfig (see Config/Signing.xcconfig)" >&2
    exit 1
fi
AUTH=()
if [[ -n "${ASC_KEY:-}" ]]; then
    ASC_KEY="$(cd "$(dirname "$ASC_KEY")" && pwd)/$(basename "$ASC_KEY")"
    AUTH=(-authenticationKeyPath "$ASC_KEY"
          -authenticationKeyID "${ASC_KEY_ID:?set ASC_KEY_ID}" -authenticationKeyIssuerID "${ASC_ISSUER:?set ASC_ISSUER}")
fi

PROFILES=()   # bundle ID, profile name, … for manual signing
if [[ "${DISTRIBUTION_CERTIFICATE:-0}" == "1" ]]; then
    [[ -n "${ASC_KEY:-}" ]] || { echo "error: DISTRIBUTION_CERTIFICATE=1 needs ASC_KEY, ASC_KEY_ID and ASC_ISSUER" >&2; exit 1; }
    BUNDLE_ID="$(xcodebuild -project "$PROJECT" -target OneOrMany -configuration Release -showBuildSettings -json \
        "${SETTINGS[@]}" 2> /dev/null | plutil -extract "0.buildSettings.PRODUCT_BUNDLE_IDENTIFIER" raw -)"
    [[ -n "$BUNDLE_ID" ]] || { echo "error: couldn't read the app's bundle ID" >&2; exit 1; }
    swift scripts/provisioning-profiles.swift "$ASC_KEY" "$ASC_KEY_ID" "$ASC_ISSUER" "$BUNDLE_ID"
    PROFILES+=("$BUNDLE_ID" "$BUNDLE_ID App Store (CI)")
    SETTINGS+=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution"
               PROVISIONING_PROFILE_SPECIFIER='$(PRODUCT_BUNDLE_IDENTIFIER) App Store (CI)')
fi

rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"} \
    "${SETTINGS[@]}" archive -quiet

OPTIONS_DIR="$(mktemp -d)"
trap 'rm -rf "$OPTIONS_DIR"' EXIT
OPTIONS="$OPTIONS_DIR/ExportOptions.plist"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>$([[ "${UPLOAD:-1}" == "1" ]] && echo upload || echo export)</string>
$(if [[ ${#PROFILES[@]} -gt 0 ]]; then
    echo "    <key>signingStyle</key><string>manual</string>"
    echo "    <key>signingCertificate</key><string>Apple Distribution</string>"
    echo "    <key>provisioningProfiles</key><dict>"
    for ((i = 0; i < ${#PROFILES[@]}; i += 2)); do echo "        <key>${PROFILES[i]}</key><string>${PROFILES[i+1]}</string>"; done
    echo "    </dict>"
else
    echo "    <key>signingStyle</key><string>automatic</string>"
fi)
$([[ -n "${DEVELOPMENT_TEAM:-}" ]] && echo "    <key>teamID</key><string>$DEVELOPMENT_TEAM</string>")
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" -exportOptionsPlist "$OPTIONS" \
    -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE/Info.plist")"
if [[ "${UPLOAD:-1}" == "1" ]]; then
    echo "Uploaded One or Many $VERSION ($BUILD). It shows up in App Store Connect ▸ TestFlight once Apple has processed it."
else
    echo "Exported $EXPORT/OneOrMany.ipa ($VERSION, $BUILD)"
fi
