#!/usr/bin/env bash
# Plays day 1 through the real game on a virtual display and saves a
# screenshot of every screen, for checking layouts without a monitor (a
# cloud session, say). Linux only: needs xvfb-run. Renders with OpenGL in
# software, since there's no GPU.
#
#   tools/screenshots.sh                 # into build/screenshots/
#   tools/screenshots.sh /some/folder
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"
OUT="$(mkdir -p "${1:-$ROOT/build/screenshots}" && cd "${1:-$ROOT/build/screenshots}" && pwd)"

if ! command -v xvfb-run > /dev/null; then
  echo "xvfb-run is missing (apt install xvfb)." >&2
  exit 1
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

RUNNER="$ROOT/tools/screenshots/play_a_day.gd" SHOT_DIR="$OUT" \
  xvfb-run -a -s "-screen 0 1280x800x24" \
  "$GODOT" --path "$ROOT/game" --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1280x800 -s "$ROOT/tools/boot_runner.gd" 2>&1 | tee "$log" | grep "^shot " || true

if grep -E "^(SCRIPT ERROR|USER ERROR):" "$log" > /dev/null; then
  grep -A2 -E "^(SCRIPT ERROR|USER ERROR):" "$log" >&2
  echo "Screenshots failed: see the errors above." >&2
  exit 1
fi
echo "Screenshots are in $OUT"
