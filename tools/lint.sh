#!/usr/bin/env bash
# Fast static check (a few seconds): compiles every game script with the
# project's strict typing rules, instantiates every scene, and checks that
# scene text uses translation keys. Godot's own --check-only can't do this
# because it doesn't load the autoloads, so valid scripts fail there.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"

# Refresh the import so newly added class_name scripts are known.
"$GODOT" --headless --path "$ROOT/game" --import > /dev/null 2>&1
"$GODOT" --headless --path "$ROOT/game" -s res://addons/gut/gut_cmdln.gd -gexit -gselect=test_project_integrity
