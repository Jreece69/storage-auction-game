#!/usr/bin/env bash
# Checks the game as it ships, not as the editor sees it: exports a .pck with
# the Windows preset's file filters, boots it headless with the Linux engine,
# then plays day 1 through it. A file missing from the export (data,
# translations, a scene) fails here instead of on a player's PC.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh" --templates)}"
OUT="$ROOT/build/smoke"
PCK="$OUT/game.pck"

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/game" --import > /dev/null 2>&1
"$GODOT" --headless --path "$ROOT/game" --export-pack "Windows Desktop" "$PCK" > "$OUT/export.log" 2>&1 || {
  cat "$OUT/export.log"
  echo "Export smoke test: the export failed." >&2
  exit 1
}

log="$OUT/run.log"
fail() {
  cat "$log"
  echo "Export smoke test failed: $1" >&2
  exit 1
}

echo "== Booting the exported game"
"$GODOT" --headless --main-pack "$PCK" --quit-after 300 > "$log" 2>&1 || fail "it didn't boot."
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR):" "$log" > /dev/null; then
  fail "Godot reported errors while booting."
fi

echo "== Playing day 1 in the exported game"
RUNNER="$ROOT/tools/screenshots/play_a_day.gd" \
  "$GODOT" --headless --main-pack "$PCK" -s "$ROOT/tools/boot_runner.gd" > "$log" 2>&1 || fail "the day didn't play."
if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR):" "$log" > /dev/null; then
  fail "Godot reported errors while playing."
fi
grep -q "Played day 1 through to the end-of-day summary." "$log" || fail "the day didn't reach the summary."
echo "Export smoke test passed: the exported game boots and plays a full day."
