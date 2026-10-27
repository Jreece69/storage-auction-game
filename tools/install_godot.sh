#!/usr/bin/env bash
# Downloads the pinned Godot (see tools/GODOT_VERSION) into .tools/ and checks
# it against the official SHA-512 sums. Safe to run repeatedly: anything
# already present is reused.
#
#   tools/install_godot.sh              # the Godot binary only
#   tools/install_godot.sh --templates  # plus the Windows export templates
#
# Progress goes to stderr. The only thing printed to stdout is the path to the
# Godot binary, so scripts can do: GODOT="$(tools/install_godot.sh)"
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/tools/GODOT_VERSION")"
TAG="${VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${TAG}"
DEST="$ROOT/.tools/godot/$VERSION"
TEMPLATES="$ROOT/.tools/templates/${VERSION}.stable"

want_templates=false
if [[ "${1:-}" == "--templates" ]]; then
  want_templates=true
fi

mkdir -p "$DEST"

fetch_sums() {
  if [[ ! -f "$DEST/SHA512-SUMS.txt" ]]; then
    curl -fsSL --retry 3 -o "$DEST/SHA512-SUMS.txt" "$BASE/SHA512-SUMS.txt"
  fi
}

verify() {
  (cd "$DEST" && grep " $1\$" SHA512-SUMS.txt | sha512sum -c --quiet -)
}

if [[ ! -x "$DEST/godot" ]]; then
  fetch_sums
  zip="Godot_v${TAG}_linux.x86_64.zip"
  echo "Downloading Godot $VERSION..." >&2
  curl -fsSL --retry 3 -o "$DEST/$zip" "$BASE/$zip"
  verify "$zip"
  unzip -q -o "$DEST/$zip" -d "$DEST"
  mv "$DEST/Godot_v${TAG}_linux.x86_64" "$DEST/godot"
  rm "$DEST/$zip"
fi

if $want_templates && [[ ! -f "$TEMPLATES/windows_release_x86_64.exe" ]]; then
  fetch_sums
  tpz="Godot_v${TAG}_export_templates.tpz"
  echo "Downloading export templates (1.3 GB, cached after the first run)..." >&2
  curl -fsSL --retry 3 -o "$DEST/$tpz" "$BASE/$tpz"
  verify "$tpz"
  mkdir -p "$TEMPLATES"
  # Keep only what a 64-bit Windows export needs.
  unzip -q -o -j "$DEST/$tpz" templates/version.txt 'templates/windows_*_x86_64*.exe' -d "$TEMPLATES"
  rm "$DEST/$tpz"
fi

# Godot looks for export templates in its own data folder.
if [[ -d "$TEMPLATES" ]]; then
  data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
  mkdir -p "$data_dir"
  ln -sfn "$TEMPLATES" "$data_dir/${VERSION}.stable"
fi

echo "$DEST/godot"
