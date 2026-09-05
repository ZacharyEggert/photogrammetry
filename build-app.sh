#!/bin/sh
# ponytail: SwiftPM-only bundle (no Xcode needed); Photogrammetry.xcodeproj shares this Info.plist
set -e
swift build -c release
APP=Photogrammetry.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/Photogrammetry" "$APP/Contents/MacOS/"
swift tools/makeicon.swift
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP"
