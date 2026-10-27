# Storage Auction Game (working title)

A single-player storage auction tycoon for PC, built in Godot 4.7. Win lockers
by reading your rivals, haul the contents, add value, and sell from your own
shop.

Private, commercial project. All rights reserved; no license is granted to
use, copy or distribute any part of it.

- **The plan:** [`docs/DESIGN.md`](docs/DESIGN.md)
- **Decisions made while building:** [`docs/DECISIONS.md`](docs/DECISIONS.md)
- **Context for Claude Code sessions:** [`CLAUDE.md`](CLAUDE.md)
- **Third-party assets and licenses:** [`CREDITS.md`](CREDITS.md)

## Play a test build

1. On GitHub, open **Actions**, then the newest green **CI** run on `main`.
2. Under **Artifacts**, download **windows-build** and unzip it.
3. Run `StorageAuctionGame.exe`. Windows may warn that the build is unsigned:
   choose **More info**, then **Run anyway**.

## Work on it

- Godot version: [`tools/GODOT_VERSION`](tools/GODOT_VERSION) (4.7.2).
- Open `game/project.godot` in the Godot editor. The GUT panel runs the tests.
- From a terminal (Linux, macOS, or Git Bash on Windows): `tools/test.sh`
  runs everything CI runs; `tools/export_windows.sh` builds the `.exe`.
