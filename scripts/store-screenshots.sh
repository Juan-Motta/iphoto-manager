#!/usr/bin/env bash
# Builds the Mac App Store screenshots (2880×1800) in docs/app-store/screenshots/:
# each is a real capture of the app in demo mode (fake iPhone, generated pictures)
# under a caption. Captures are 2× when a Retina screen is connected.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs/app-store/screenshots"
RAW="$(mktemp -d)"
trap 'rm -rf "$RAW"' EXIT

# scene | caption | subtitle
SHOTS=(
  "library|Free up space on your iPhone|See every photo and video, grouped by day. Pick a few or all of them."
  "confirmSave|Save first, then delete|Every copy is checked on your Mac before anything leaves your iPhone."
  "preview|Look before you decide|Open any photo or video full size, right from the library."
  "progress|Watch every item finish|See each photo being copied, verified and removed."
  "waiting|Just plug in your iPhone|Connect, unlock, tap Trust. The app does the rest."
)

SCENES=()
for shot in "${SHOTS[@]}"; do SCENES+=("${shot%%|*}"); done
OUT_DIR="$RAW" MAX_SIZE=0 "$ROOT/scripts/screenshots.sh" "${SCENES[@]}" >/dev/null

mkdir -p "$OUT"
index=1
for shot in "${SHOTS[@]}"; do
  IFS='|' read -r scene title subtitle <<<"$shot"
  out="$OUT/$index-$scene.png"
  swift "$ROOT/scripts/artwork.swift" store-shot "$RAW/$scene.png" "$out" "$title" "$subtitle"
  echo "✓ docs/app-store/screenshots/$index-$scene.png"
  index=$((index + 1))
done
