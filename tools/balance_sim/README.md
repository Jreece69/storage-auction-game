# Balance sim

Headless bot runs that check the tuning targets in
[`docs/BALANCE.md`](../../docs/BALANCE.md). Run it with
`tools/balance_sim.sh` from the repo root; that page explains the bots and
the report.

- `run.gd` plays the runs and writes the Markdown report.
- The bot itself is `game/scripts/systems/sim/balance_bot.gd`, so it uses the
  real rules and has unit tests.
