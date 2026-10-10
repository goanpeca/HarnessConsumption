#!/usr/bin/env bash
# Builds a release binary and wraps it in build/Agent Consumption.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product AgentConsumption
app="build/Agent Consumption.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
binary="$app/Contents/MacOS/AgentConsumption"
cp "$(swift build -c release --show-bin-path)/AgentConsumption" "$binary"
# SwiftPM's build system stamps the binary with SDK 14.0 (the deployment target). macOS then draws
# the app in its old compatibility style: small corners, flat chrome. Record the real SDK so the
# menu bar panel gets the current system look.
vtool -set-build-version macos 14.0 "$(xcrun --show-sdk-version)" -replace -output "$binary" "$binary"
cp Resources/Info.plist "$app/Contents/"
codesign --force --sign - "$app"
echo "$app"
