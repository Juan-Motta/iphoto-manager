#!/usr/bin/env bash
# Regenerates App/Resources/AppIcon.icns (and the README copy) from App/Resources/AppIcon-source.png.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift "$ROOT/scripts/artwork.swift" icon "$ROOT/App/Resources/AppIcon-source.png" "$WORK/icon.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$WORK/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

mkdir -p "$ROOT/App/Resources" "$ROOT/docs/images"
iconutil -c icns "$ICONSET" -o "$ROOT/App/Resources/AppIcon.icns"
sips -z 256 256 "$WORK/icon.png" --out "$ROOT/docs/images/icon.png" >/dev/null
echo "✓ App/Resources/AppIcon.icns"
