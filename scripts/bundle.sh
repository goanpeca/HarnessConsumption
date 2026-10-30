#!/usr/bin/env bash
# Builds a release binary and wraps it in build/Harness Consumption.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product HarnessConsumption
app="build/Harness Consumption.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
binary="$app/Contents/MacOS/HarnessConsumption"
cp "$(swift build -c release --show-bin-path)/HarnessConsumption" "$binary"
# SwiftPM's build system stamps the binary with SDK 14.0 (the deployment target). macOS then draws
# the app in its old compatibility style: small corners, flat chrome. Record the real SDK so the
# menu bar panel gets the current system look.
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace -output "$binary" "$binary"
mkdir -p "$app/Contents/Resources"
cp Resources/AppIcon.icns "$app/Contents/Resources/"
cp Resources/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "$app"
