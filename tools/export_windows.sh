#!/usr/bin/env bash
# Exports a Windows release build to build/windows/. Downloads the pinned
# export templates on first use.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$("$ROOT/tools/install_godot.sh" --templates)"
OUT="$ROOT/build/windows"

rm -rf "$OUT"
mkdir -p "$OUT"

"$GODOT" --headless --path "$ROOT/game" --import
"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Desktop" "$OUT/StorageAuctionGame.exe"

if [[ ! -s "$OUT/StorageAuctionGame.exe" ]]; then
  echo "Export failed: no StorageAuctionGame.exe was produced." >&2
  exit 1
fi
cp "$ROOT/tools/windows_build_readme.txt" "$OUT/README.txt"
ls -la "$OUT"
