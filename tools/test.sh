#!/usr/bin/env bash
# Runs what CI runs before the export: import, unit tests, boot check.
# Exits non-zero if anything fails. Set GODOT to use a different binary.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"
export GODOT

echo "== Importing assets"
"$GODOT" --headless --path "$ROOT/game" --import

echo "== Unit tests"
"$ROOT/tools/gut.sh"

echo "== Boot check"
"$ROOT/tools/boot_check.sh"
