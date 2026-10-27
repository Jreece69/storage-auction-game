#!/usr/bin/env bash
# The balance sim: a bot plays many runs of 30 in-game days at a few bidding
# styles and prints a report of cash over time and how lockers pay off.
# Takes a minute or two. Results feed docs/BALANCE.md.
#
#   tools/balance_sim.sh                         # 200 runs per style
#   tools/balance_sim.sh --seeds=50 --days=14
#   tools/balance_sim.sh --out=build/balance.md  # also write the report
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"

# New class names (BalanceBot) need an import to be found.
"$GODOT" --headless --path "$ROOT/game" --import > /dev/null 2>&1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

args=()
for arg in "$@"; do
  # Relative --out paths are relative to where the script was started.
  if [[ "$arg" == --out=* ]]; then
    out="${arg#--out=}"
    [[ "$out" != /* ]] && out="$PWD/$out"
    mkdir -p "$(dirname "$out")"
    arg="--out=$out"
  fi
  args+=("$arg")
done

"$GODOT" --headless --path "$ROOT/game" -s "$ROOT/tools/balance_sim/run.gd" -- "${args[@]}" 2>&1 \
  | grep -v -E "^Godot Engine v" | tee "$log"

if grep -q -E "^(SCRIPT ERROR|USER ERROR|ERROR):" "$log"; then
  echo "The balance sim failed: see the errors above." >&2
  exit 1
fi
