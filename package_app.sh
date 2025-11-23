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

echo "Code signing..."
# Ad-hoc sign the binary to enable notifications
# Using entitlements helps the system validate the app capabilities
codesign --force --deep --sign - --entitlements "Chronology.entitlements" "$APP_BUNDLE"

echo "Copying icon..."
if [ -f "Chronology.icns" ]; then
    # Rename icon to match app name in resources
    cp "Chronology.icns" "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
fi

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
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSUserNotificationsUsageDescription</key>
    <string>Chronology needs permission to send you reminders before your classes start.</string>
</dict>
</plist>
EOF

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
