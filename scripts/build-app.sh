#!/usr/bin/env bash
# Builds a release PhotoManager.app bundle in build/.
#
#   ./scripts/build-app.sh                 # ad-hoc signed, version 1.0.0
#   VERSION=1.2.0 ./scripts/build-app.sh
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-app.sh
#
# Needs Xcode 26+ (SwiftUI macros). Builds for the Mac's own architecture.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="iPhoto Manager"
EXECUTABLE="PhotoManager"
BUNDLE_ID="${BUNDLE_ID:-com.iphotomanager.app}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc signature

OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"

echo "→ Building $EXECUTABLE (release)"
swift build -c release --package-path "$ROOT/App" --product "$EXECUTABLE"
BIN_DIR="$(swift build -c release --package-path "$ROOT/App" --show-bin-path)"

echo "→ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSCameraUsageDescription</key><string>iPhoto Manager reads the photos and videos on your connected iPhone.</string>
</dict>
</plist>
PLIST

if [ -f "$ROOT/App/Resources/AppIcon.icns" ]; then
  cp "$ROOT/App/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi

echo "→ Signing ($([ "$SIGN_IDENTITY" = "-" ] && echo ad-hoc || echo "$SIGN_IDENTITY"))"
SIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
[ "$SIGN_IDENTITY" != "-" ] && SIGN_ARGS+=(--options runtime --timestamp)
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict "$APP"

echo "✓ $APP"
