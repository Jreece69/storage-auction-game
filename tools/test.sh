#!/usr/bin/env bash
# Runs what CI runs before the export: import, unit tests, boot check.
# Exits non-zero if anything fails. Set GODOT to use a different binary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"

echo "== Importing assets"
"$GODOT" --headless --path "$ROOT/game" --import

echo "== Unit tests"
"$GODOT" --headless --path "$ROOT/game" -s res://addons/gut/gut_cmdln.gd -gexit

echo "== Boot check"
GODOT="$GODOT" "$ROOT/tools/boot_check.sh"
