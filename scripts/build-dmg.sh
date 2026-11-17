#!/usr/bin/env bash
# Builds the app and packs it into dist/PhotoManager-<version>.dmg: a styled installer window
# with the app, an arrow and an Applications shortcut for drag-to-install.
#
#   ./scripts/build-dmg.sh
#   VERSION=1.2.0 ./scripts/build-dmg.sh
#   SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=my-profile ./scripts/build-dmg.sh
#
# NOTARY_PROFILE is a keychain profile created once with
# `xcrun notarytool store-credentials`. Without it the DMG is not notarized.
#
# Styling the window drives Finder through AppleScript; the first run may ask to allow
# the terminal to control Finder. Set PLAIN_DMG=1 to skip the styling (for CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Photo Manager"
VOLUME="$APP_NAME"
VERSION="${VERSION:-1.0.0}"
export VERSION

"$ROOT/scripts/build-app.sh"

APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
DMG="$DIST/PhotoManager-$VERSION.dmg"
WORK="$(mktemp -d)"
MOUNT=""
cleanup() {
  [ -n "$MOUNT" ] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "→ Preparing installer contents"
STAGING="$WORK/staging"
mkdir -p "$STAGING/.background"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
# Background at 1× and 2× in one TIFF so it stays sharp on Retina screens.
swift "$ROOT/scripts/artwork.swift" dmg-background "$WORK/bg.png" 1
swift "$ROOT/scripts/artwork.swift" dmg-background "$WORK/bg@2x.png" 2
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$STAGING/.background/background.tiff" 2>/dev/null
if [ -f "$APP/Contents/Resources/AppIcon.icns" ]; then
  cp "$APP/Contents/Resources/AppIcon.icns" "$STAGING/.VolumeIcon.icns"
fi

echo "→ Creating disk image"
RW="$WORK/rw.dmg"
hdiutil create -volname "$VOLUME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$RW" -quiet 2>/dev/null
MOUNT="$(hdiutil attach "$RW" -readwrite -noverify -noautoopen 2>/dev/null | sed -n 's|.*\(/Volumes/.*\)$|\1|p' | head -1)"
[ -n "$MOUNT" ] || { echo "✗ Could not mount the disk image" >&2; exit 1; }

# Custom volume icon (needs SetFile from Xcode; skipped without it).
if [ -f "$MOUNT/.VolumeIcon.icns" ] && xcrun --find SetFile >/dev/null 2>&1; then
  xcrun SetFile -a C "$MOUNT"
fi

if [ "${PLAIN_DMG:-0}" != "1" ]; then
  echo "→ Styling the installer window"
  DISK_NAME="$(basename "$MOUNT")"
  # Bounds include the 28 pt title bar so the content is 660×400; positions match the arrow in scripts/artwork.swift.
  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$DISK_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 548}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 120
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "$APP_NAME.app" of container window to {170, 190}
    set position of item "Applications" of container window to {490, 190}
    close
    open
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
fi

sync
hdiutil detach "$MOUNT" -quiet
MOUNT=""

echo "→ Compressing $DMG"
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" -quiet 2>/dev/null

if [ "${SIGN_IDENTITY:--}" != "-" ]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "→ Notarizing"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
