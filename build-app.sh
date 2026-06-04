#!/bin/bash
set -e

APP_NAME="MultiDock"
APP_BUNDLE="${APP_NAME}.app"
SOURCES="Sources/MultiDock"
SWIFTC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk

SIGN_IDENTITY="Developer ID Application: Mehak Kalra (UC582U3Y82)"
BUNDLE_ID="com.houseofpm.multidock"
NOTARY_PROFILE="MultiDock-Notary"
NOTARIZE=true
if [[ "$1" == "--skip-notarize" ]]; then
  NOTARIZE=false
  echo "⚡ Skipping notarization (dev build)"
fi

echo "🔨 Building ${APP_NAME}..."

"$SWIFTC" \
  -sdk "$SDK" \
  -target arm64-apple-macosx13.0 \
  -framework AppKit \
  -framework ApplicationServices \
  -O \
  "${SOURCES}/DockReader.swift" \
  "${SOURCES}/DockItemButton.swift" \
  "${SOURCES}/DockWindow.swift" \
  "${SOURCES}/AppDelegate.swift" \
  "${SOURCES}/main.swift" \
  -o "${APP_NAME}_bin"

echo "📦 Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mv "${APP_NAME}_bin" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Build app icon from iconset if present
if [ -d "MultiDock.iconset" ]; then
  iconutil -c icns MultiDock.iconset -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
  echo "🎨 App icon added"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MultiDock</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>MultiDock</string>
    <key>CFBundleDisplayName</key>
    <string>MultiDock</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>MultiDock needs Accessibility access to bring app windows to the front on secondary monitors.</string>
</dict>
</plist>
PLIST

echo "✍️  Signing ${APP_BUNDLE}..."
codesign --deep --force --options runtime \
  --sign "${SIGN_IDENTITY}" \
  --identifier "${BUNDLE_ID}" \
  "${APP_BUNDLE}"

echo "🔍 Verifying signature..."
codesign --verify --deep --strict "${APP_BUNDLE}" && echo "   Signature OK"

if [ "$NOTARIZE" = true ]; then
  echo "📬 Notarizing (this takes ~1-2 minutes)..."
  ditto -c -k --keepParent "${APP_BUNDLE}" "${APP_NAME}.zip"

  xcrun notarytool submit "${APP_NAME}.zip" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

  echo "📎 Stapling notarization ticket..."
  xcrun stapler staple "${APP_BUNDLE}"
  rm -f "${APP_NAME}.zip"
else
  echo "⚠️  Not notarized — for testing only, don't distribute this build"
fi

echo "🚀 Installing to /Applications/..."
pkill -x MultiDock 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/${APP_BUNDLE}"
cp -R "${APP_BUNDLE}" /Applications/

echo ""
echo "✅ Signed, notarized & installed — /Applications/MultiDock.app"
echo ""
echo "Launching..."
open "/Applications/${APP_BUNDLE}"
