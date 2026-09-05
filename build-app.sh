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
# Xcode expands $(PRODUCT_BUNDLE_IDENTIFIER); do the same here.
BUNDLE_ID=$(sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' Photogrammetry.xcodeproj/project.pbxproj | head -1)
sed "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|" Info.plist > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "built $APP"
