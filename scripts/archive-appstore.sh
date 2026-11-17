#!/usr/bin/env bash
# Archives Easy Photo Saver for the Mac App Store and exports (or uploads) it.
#
#   TEAM_ID=ABCDE12345 ./scripts/archive-appstore.sh            # export build/AppStore/*.pkg
#   TEAM_ID=ABCDE12345 UPLOAD=1 ./scripts/archive-appstore.sh   # upload to App Store Connect
#   VERSION=1.1.0 BUILD_NUMBER=7 TEAM_ID=… ./scripts/archive-appstore.sh
#
# Needs an Apple Developer account signed in to Xcode (Settings › Accounts). Signing and
# provisioning profiles are managed automatically. The same can be done from Xcode with
# Product › Archive.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer team ID}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
ARCHIVE="$ROOT/build/iPhotoManager.xcarchive"
EXPORT="$ROOT/build/AppStore"
OPTIONS="$(mktemp -d)/ExportOptions.plist"

echo "→ Archiving $VERSION ($BUILD_NUMBER)"
xcodebuild archive -project "$ROOT/iPhotoManager.xcodeproj" -scheme iPhotoManager -configuration Release \
  -destination "generic/platform=macOS" -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" -quiet

cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>destination</key><string>$([ "${UPLOAD:-0}" = "1" ] && echo upload || echo export)</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

echo "→ $([ "${UPLOAD:-0}" = "1" ] && echo "Uploading to App Store Connect" || echo "Exporting to $EXPORT")"
rm -rf "$EXPORT"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OPTIONS" \
  -exportPath "$EXPORT" -allowProvisioningUpdates -quiet
echo "✓ Done"
