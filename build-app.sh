#!/bin/sh
# ponytail: hand-rolled bundle so `swift build` output is runnable without an Xcode target.
# Needs Xcode for actool (the app icon lives in Resources/Appicon.icon); everything else is SwiftPM.
# Photogrammetry.xcodeproj shares this Info.plist and the same .icon.
set -e
swift build -c release
APP=Photogrammetry.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Photogrammetry" "$APP/Contents/MacOS/"

# Xcode expands $(PRODUCT_BUNDLE_IDENTIFIER) and reads the icon name from the build settings;
# do the same here so the two build paths can't drift.
PROJ=Photogrammetry.xcodeproj/project.pbxproj
BUNDLE_ID=$(sed -n 's/.*PRODUCT_BUNDLE_IDENTIFIER = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' "$PROJ" | head -1)
ICON=$(sed -n 's/.*ASSETCATALOG_COMPILER_APPICON_NAME = "\{0,1\}\([^";]*\)"\{0,1\};.*/\1/p' "$PROJ" | head -1)
DEPLOY=$(sed -n 's/.*MACOSX_DEPLOYMENT_TARGET = \([0-9.]*\);.*/\1/p' "$PROJ" | head -1)

sed "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|$BUNDLE_ID|" Info.plist > "$APP/Contents/Info.plist"

xcrun actool "Resources/$ICON.icon" \
    --compile "$APP/Contents/Resources" \
    --app-icon "$ICON" \
    --output-partial-info-plist "$APP/Contents/Resources/.icon.plist" \
    --bundle-identifier "$BUNDLE_ID" \
    --platform macosx --target-device mac \
    --minimum-deployment-target "$DEPLOY" \
    --enable-on-demand-resources NO \
    --output-format human-readable-text > /dev/null
# actool reports the icon keys in a partial plist; fold them into the real one.
for KEY in CFBundleIconFile CFBundleIconName; do
    VALUE=$(/usr/libexec/PlistBuddy -c "Print :$KEY" "$APP/Contents/Resources/.icon.plist" 2>/dev/null) || continue
    plutil -replace "$KEY" -string "$VALUE" "$APP/Contents/Info.plist"
done
rm -f "$APP/Contents/Resources/.icon.plist"

codesign --force --sign - "$APP"
echo "built $APP"
