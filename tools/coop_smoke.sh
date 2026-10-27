#!/usr/bin/env bash
# Plays one co-op day over the real network: a host and friends, each a
# separate headless copy of the game on this machine, connected by ENet on
# localhost. Each is a bot making its player's moves (tools/coop/bot_player.gd).
# Passes when every player finishes the day and they all agree on the run and
# the day, down to the last item and dollar.
#
#   tools/coop_smoke.sh            # host plus 2 friends
#   tools/coop_smoke.sh 4          # a full crew of four
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-$("$ROOT/tools/install_godot.sh")}"
PLAYERS="${1:-3}"
PORT="${COOP_PORT:-47321}"
OUT="$ROOT/build/coop"

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/game" --import > /dev/null 2>&1

run_bot() {  # role name output-file
  COOP_ROLE="$1" COOP_NAME="$2" COOP_OUT="$3" COOP_PORT="$PORT" COOP_PLAYERS="$PLAYERS" COOP_SEED=2026 \
    RUNNER="$ROOT/tools/coop/bot_player.gd" \
    timeout 150 "$GODOT" --headless --path "$ROOT/game" -s "$ROOT/tools/boot_runner.gd" > "$3.log" 2>&1
}

pids=()
run_bot host Host "$OUT/host.json" & pids+=($!)
sleep 2
for seat in $(seq 2 "$PLAYERS"); do
  run_bot join "Friend$seat" "$OUT/friend$seat.json" & pids+=($!)
done

failed=0
for pid in "${pids[@]}"; do
  wait "$pid" || failed=1
done

for log in "$OUT"/*.log; do
  if grep -E "^(ERROR|SCRIPT ERROR|USER ERROR):" "$log" > /dev/null; then
    echo "== $log" && cat "$log"
    failed=1
  fi
done
if [[ $failed -ne 0 ]]; then
  for log in "$OUT"/*.log; do echo "== $log"; tail -20 "$log"; done
  echo "Co-op smoke test failed: a player didn't finish the day cleanly." >&2
  exit 1
fi

python3 - "$OUT" "$PLAYERS" <<'PY'
import json, sys, pathlib
out, players = pathlib.Path(sys.argv[1]), int(sys.argv[2])
reports = [json.loads((out / "host.json").read_text())] + [json.loads((out / f"friend{seat}.json").read_text()) for seat in range(2, players + 1)]
host = reports[0]
assert len(host["crew"]) == players, f"crew of {len(host['crew'])}, expected {players}"
for report in reports[1:]:
    for part in ("crew", "run", "today", "summary"):
        if report[part] != host[part]:
            sys.exit(f"{report['member']}'s {part} differs from the host's")
ledger = host["today"]["ledger"]
print(f"All {players} players agree: {ledger['lockers_won']} locker won, "
      f"{ledger['items_sold']} items sold for ${ledger['sales']}, "
      f"friendly fire {sum(m['friendly_fire'] for m in ledger['members'].values())} times.")
PY
echo "Co-op smoke test passed."
