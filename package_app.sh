#!/bin/bash

set -e

APP_NAME="Chronology"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"

echo "Building release configuration..."
swift build -c release

echo "Creating App Bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Copying binary..."
# The build target is still named Chronology in Package.swift
cp "$BUILD_DIR/Chronology" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Compiling app icon..."
# Liquid Glass icon from Icon Composer, shared with the iOS app
# actool resolves relative paths against $PWD, which can be stale, so pass absolute ones
ROOT="$(cd "$(dirname "$0")" && pwd -P)"
xcrun actool "$ROOT/Design/AppIcon.icon" --compile "$ROOT/$APP_BUNDLE/Contents/Resources" \
    --platform macosx --minimum-deployment-target 26.0 --app-icon AppIcon \
    --output-partial-info-plist "$ROOT/.build/icon-partial.plist" >/dev/null
test -f "$ROOT/$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.codingpasanga.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>4.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>Chronology needs permission to send you reminders before your classes start.</string>
    <key>NSUserNotificationsProvidesAppNotificationSettings</key>
    <true/>
</dict>
</plist>
EOF

echo "Code signing..."
# Sign last: any change to the bundle after signing (Info.plist, icon) invalidates the seal.
# Ad-hoc signing binds Info.plist so the bundle identifier is used for notifications
codesign --force --deep --sign - --entitlements "Chronology.entitlements" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Preparing DMG content..."
rm -rf "dmg_content"
mkdir "dmg_content"
cp -r "$APP_BUNDLE" "dmg_content/"
ln -s /Applications "dmg_content/Applications"

echo "Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "$APP_NAME" -srcfolder "dmg_content" -ov -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

rm -rf "dmg_content"

echo "Done! Created $DMG_NAME"
