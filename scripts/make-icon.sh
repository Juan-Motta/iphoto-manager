#!/usr/bin/env bash
# Regenerates the app icon in App/Xcode/Assets.xcassets (and the README copy)
# from App/Resources/AppIcon-source.png.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/artwork.swift" icon "$ROOT/App/Resources/AppIcon-source.png" "$WORK/icon.png"

ICONSET="$ROOT/App/Xcode/Assets.xcassets/AppIcon.appiconset"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$ROOT/docs/images"
sips -z 256 256 "$WORK/icon.png" --out "$ROOT/docs/images/icon.png" >/dev/null
echo "✓ App/Xcode/Assets.xcassets/AppIcon.appiconset"
