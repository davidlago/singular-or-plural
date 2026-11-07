#!/usr/bin/env bash
# Captures the App Store screenshots from the iPhone 18 Pro simulator (1206 × 2622, the required 6.3-inch set) into
# docs/app-store/iphone-6.3/. Builds a Debug build and launches it in screenshot mode (OneOrMany/App/ScreenshotMode.swift)
# once per scene, with sample progress and the status bar at 9:41.
#
#   DEVICE="iPhone 18 Pro Max" OUT=docs/app-store/iphone scripts/screenshots.sh   # the 6.9-inch set (1320 × 2868)
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-iPhone 18 Pro}"
OUT="${OUT:-docs/app-store/iphone-6.3}"
SCENES=(card miss streak summary home map stats)

udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and "iOS" in runtime:
            print(d["udid"]); sys.exit()' "$DEVICE")"
[[ -n "$udid" ]] || { echo "error: no simulator named $DEVICE" >&2; exit 1; }

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b > /dev/null
xcrun simctl ui "$udid" appearance light
xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

xcodebuild build -project OneOrMany.xcodeproj -scheme OneOrMany -configuration Debug \
    -destination "id=$udid" -derivedDataPath build/DerivedData -quiet CODE_SIGNING_ALLOWED=NO
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/OneOrMany.app
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
xcrun simctl install "$udid" "$APP"

mkdir -p "$OUT"
i=1
for scene in "${SCENES[@]}"; do
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -screenshot "$scene" > /dev/null
    sleep 3
    file="$OUT/$(printf '%02d' "$i")-$scene.png"
    xcrun simctl io "$udid" screenshot "$file" > /dev/null 2>&1
    echo "$file"
    i=$((i + 1))
done
xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$udid" clear
