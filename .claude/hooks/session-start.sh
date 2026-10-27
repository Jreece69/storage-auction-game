#!/bin/bash
# Gets a Claude Code cloud session ready to work on the game: installs the
# pinned Godot (checksum-verified, reused from the cached container after the
# first run) and imports the project so tests run straight away.
set -euo pipefail

# Cloud sessions only. On Jack's PC the Godot editor is used directly.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

godot="$(tools/install_godot.sh)"

# Make `godot` and $GODOT available to every command in the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GODOT=\"$godot\"" >> "$CLAUDE_ENV_FILE"
  echo "export PATH=\"$(dirname "$godot"):\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Build the import cache so GUT and the boot check work on a fresh clone.
"$godot" --headless --path game --import > /dev/null 2>&1

# Anything printed here is added to the session's context.
echo "Godot $(cat tools/GODOT_VERSION) is installed (\$GODOT, or \`godot\` on PATH). Before pushing, run tools/test.sh; tools/lint.sh is the quick check."
