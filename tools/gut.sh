#!/usr/bin/env bash
# Runs the GUT tests headless, passing on any extra arguments, and fails if
# any script didn't compile. On its own, GUT skips a test file it can't load
# and still reports success, so one typo would silently switch off every test
# in that file.
#
#   tools/gut.sh                          # every test
#   tools/gut.sh -gselect=test_rng        # files whose name contains test_rng
#   tools/gut.sh -gunit_test_name=json    # tests whose name contains json
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

status=0
"$GODOT" --headless --path "$ROOT/game" -s res://addons/gut/gut_cmdln.gd -gexit "$@" 2>&1 | tee "$log" || status=$?

if grep -q -E "SCRIPT ERROR|Failed to load script" "$log"; then
  echo "FAILED: a script did not compile (see SCRIPT ERROR above). GUT skips files it can't load." >&2
  exit 1
fi
exit "$status"
