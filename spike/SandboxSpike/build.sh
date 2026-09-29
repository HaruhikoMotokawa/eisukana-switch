#!/bin/zsh
# App Sandbox を有効にしてアドホック署名した検証用アプリを build/ に作る
set -euo pipefail
cd "${0:A:h}"
APP=build/EisuKanaSpike.app
rm -rf build && mkdir -p $APP/Contents/MacOS
cp Info.plist $APP/Contents/
swiftc -O -target arm64-apple-macos14 main.swift -o $APP/Contents/MacOS/EisuKanaSpike
codesign --force --sign - --options runtime --entitlements Spike.entitlements $APP
codesign -d --entitlements - $APP 2>/dev/null | grep -A1 app-sandbox
echo "built: $APP"
