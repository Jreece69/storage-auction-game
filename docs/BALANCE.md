# Balance

The tuning targets from the plan, how each one is measured, and a log of
balance passes. Every tuning number lives in `game/data/`, never in code.

## Targets

| Target | Value | Measured by |
|---|---|---|
| First zone unlock | 15 to 20 minutes | Balance sim, then playtests |
| Main progression | 8 to 12 hours, then endless play | Playtests (Phase 4) |
| Average locker return | 1.2× to 1.6× the price paid | Balance sim |
| A ×10 or better find | About once every 30 lockers | Balance sim |
| One bid, haul and sell cycle | 3 to 5 minutes, with travel and menus under about 30 seconds | Playtests |

## Balance sim

Phase 1 builds `tools/balance_sim/`: a bot plays 30 in-game days and reports
cash over time. Every run takes a seed, so any result can be replayed exactly.

## Passes

None yet.
