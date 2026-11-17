#!/usr/bin/env bash
# Builds the app and packs it into dist/PhotoManager-<version>.dmg,
# with an Applications shortcut for drag-to-install.
#
#   ./scripts/build-dmg.sh
#   VERSION=1.2.0 ./scripts/build-dmg.sh
#   SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=my-profile ./scripts/build-dmg.sh
#
# NOTARY_PROFILE is a keychain profile created once with
# `xcrun notarytool store-credentials`. Without it the DMG is not notarized.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Photo Manager"
VERSION="${VERSION:-1.0.0}"
export VERSION

"$ROOT/scripts/build-app.sh"

APP="$ROOT/build/$APP_NAME.app"
DIST="$ROOT/dist"
DMG="$DIST/PhotoManager-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

echo "→ Creating $DMG"
mkdir -p "$DIST"
rm -f "$DMG"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

if [ "${SIGN_IDENTITY:--}" != "-" ]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

if [ -n "${NOTARY_PROFILE:-}" ]; then
  echo "→ Notarizing"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "✓ $DMG ($(du -h "$DMG" | cut -f1))"
