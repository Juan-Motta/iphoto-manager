#!/usr/bin/env bash
# Regenerates the README screenshots in docs/images/ from the real app,
# running against a fake iPhone with generated pictures (no personal photos).
#
#   ./scripts/screenshots.sh              # every scene
#   ./scripts/screenshots.sh library      # only some scenes
#   OUT_DIR=/tmp/shots MAX_SIZE=0 ./scripts/screenshots.sh   # full Retina size elsewhere
#
# The terminal running this needs Screen Recording permission
# (System Settings → Privacy & Security → Screen Recording).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT_DIR:-$ROOT/docs/images}"
MAX_SIZE="${MAX_SIZE:-1600}"   # 0 keeps the Retina capture as is
SCENES=("$@")
[ ${#SCENES[@]} -eq 0 ] && SCENES=(waiting library preview confirm progress)

swift build --package-path "$ROOT/App" --product PhotoManager >/dev/null
BIN="$(swift build --package-path "$ROOT/App" --show-bin-path)/PhotoManager"
mkdir -p "$OUT"

for scene in "${SCENES[@]}"; do
  LOG="$(mktemp)"
  # Arguments override preferences for this run only: default thumbnails, and US English
  # number and date formats (the App Store listing is English, U.S.).
  PHOTO_MANAGER_DEMO="$scene" "$BIN" -thumbnailSize standard -AppleLocale en_US -AppleLanguages '(en)' >"$LOG" 2>/dev/null &
  PID=$!
  WINDOW=""
  for _ in $(seq 1 150); do
    WINDOW="$(sed -n 's/^PHOTO_MANAGER_WINDOW=//p' "$LOG")"
    [ -n "$WINDOW" ] && break
    sleep 0.2
  done
  if [ -z "$WINDOW" ]; then
    kill "$PID" 2>/dev/null || true
    echo "✗ $scene: the app did not report its window" >&2
    exit 1
  fi
  screencapture -x -o -l"$WINDOW" "$OUT/$scene.png"
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  rm -f "$LOG"
  # Retina captures are twice the size needed on GitHub.
  [ "$MAX_SIZE" != "0" ] && sips -Z "$MAX_SIZE" "$OUT/$scene.png" >/dev/null
  echo "✓ $OUT/$scene.png"
done
