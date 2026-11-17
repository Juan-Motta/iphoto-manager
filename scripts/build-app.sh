#!/usr/bin/env bash
# Builds a release "iPhoto Manager.app" in build/ from iPhotoManager.xcodeproj,
# sandboxed, for distribution outside the App Store (see build-dmg.sh).
#
#   ./scripts/build-app.sh                 # ad-hoc signed, version 1.0.0
#   VERSION=1.2.0 ./scripts/build-app.sh
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/build-app.sh
#
# For the Mac App Store use scripts/archive-appstore.sh instead.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="iPhoto Manager"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc signature

OUT="$ROOT/build"
DERIVED="$OUT/DerivedData"

echo "→ Building $APP_NAME (release, $([ "$SIGN_IDENTITY" = "-" ] && echo ad-hoc || echo "$SIGN_IDENTITY"))"
SETTINGS=(MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
          CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGN_IDENTITY" PROVISIONING_PROFILE_SPECIFIER=
          CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)   # no get-task-allow: notarization rejects it
[ -n "${BUNDLE_ID:-}" ] && SETTINGS+=(PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID")
[ "$SIGN_IDENTITY" = "-" ] && SETTINGS+=(DEVELOPMENT_TEAM=)
[ "$SIGN_IDENTITY" != "-" ] && SETTINGS+=(OTHER_CODE_SIGN_FLAGS=--timestamp)

xcodebuild -project "$ROOT/iPhotoManager.xcodeproj" -scheme iPhotoManager -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$DERIVED" "${SETTINGS[@]}" build -quiet

rm -rf "$OUT/$APP_NAME.app"
cp -R "$DERIVED/Build/Products/Release/$APP_NAME.app" "$OUT/"
codesign --verify --strict "$OUT/$APP_NAME.app"
echo "✓ $OUT/$APP_NAME.app"
