#!/usr/bin/env bash
# Boots the game exactly as a player would (main scene, all autoloads), runs
# it for a few seconds of frames with no window, and fails if Godot reported
# any error. Run tools/test.sh first so the project is imported.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

"$GODOT" --headless --path "$ROOT/game" --quit-after 300 2>&1 | tee "$log"

if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR):" "$log" > /dev/null; then
  echo "Boot check failed: Godot reported the errors above." >&2
  exit 1
fi
echo "Boot check passed: the game started and ran 300 frames cleanly."
