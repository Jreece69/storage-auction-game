# Decisions

One line per real decision, with why. Anything in "Decisions reserved for
Jack" (see `DESIGN.md`) is never decided here; it is asked.

## Phase 0: Setup (2026-10-27)

- **The repo is `Jreece69/storage-auction-game`, private.** It's the GitHub account Claude Code is connected to; Jack created it there (Claude's GitHub app can't create repos).
- **Godot 4.7.2 stable, pinned in `tools/GODOT_VERSION`.** It was the latest 4.7.x tag; one file that CI and every script read means the version can't drift.
- **GUT 9.7.1 for tests, not gdUnit4.** Its 9.7 line is built for Godot 4.7.x, it has a plain headless command line, and it fails a test on any engine error by default.
- **GUT is vendored in `game/addons/gut/`.** The editor's test panel and CI both work from a plain clone; the export leaves it out.
- **Git LFS skips `game/addons/**/*.png`.** GUT ships nine tiny icons, and keeping them in plain git means a clone works without an LFS step.
- **Line endings are stored as LF (`* text=auto eol=lf`).** Jack works on Windows; without this, line-ending changes show up as whole-file diffs.
- **Untyped declarations are compile errors.** Enforces "static types everywhere" mechanically instead of by review. Add-ons are exempt.
- **Scene scripts sit beside their scenes in `scenes/`.** `scripts/` holds only autoloads and systems, which keeps the rule "logic in systems, scenes only display" visible in the layout.
- **Money is whole dollars in `int`.** Every price in the plan is whole dollars, and integers can't drift the way floats do.
- **Each `Rng` stream's seed is a SHA-256 hash of "master seed/stream name".** Streams stay independent of each other and identical on every platform.
- **Seeds and generator state are saved as strings.** JSON numbers are doubles and silently lose precision above 2^53, which would break replays. A test guards this.
- **Saves are written to a temp file, then swapped in.** A crash mid-save can't leave a half-written slot.
- **A save from a newer build is refused, not guessed at.** Loading it could silently drop data.
- **Settings live in `user://settings.cfg`, apart from saves.** Starting a new game never resets them.
- **Placeholder UI theme with a 28 px default font.** Text is readable at 1280×800 from the first build; Phase 2's UI theme replaces it.
- **Placeholder icon is a hand-written SVG.** Original, so there's no license question; it gets replaced before launch.
- **The Windows build is a single `.exe` with the game packed inside.** One file is the simplest thing for Jack to test; revisit for Steam in Phase 3 if needed.
- **The `.exe`'s icon and version info aren't set yet (`modify_resources = false`).** There's no final icon; switch it on in Phase 3.
- **CI runs on push only, not also on pull requests.** A pull request shows its branch's push run, and a second trigger would double the minutes a private repo gets each month.
- **CI caches Godot and only the 64-bit Windows templates** (210 MB of the 1.3 GB bundle). Runs stay fast and well inside the 10 GB cache limit.
- **Only builds from `main` are uploaded, and only the newest three are kept.** The free plan has 500 MB of artifact storage; when it fills, uploads fail and CI goes red.
- **CI pulls LFS files through the Actions cache.** Once art arrives, this stops CI from spending the account's LFS bandwidth on every run.
- **The boot check runs the real main scene for 300 frames with no window, and fails on any error line.** It proves "boots to a title screen" on a machine with no display.
- **Lint is the project-integrity test (`tools/lint.sh`), not Godot's `--check-only`.** `--check-only` doesn't load autoloads, so valid scripts that use `GameState` fail there.
- **Cloud sessions install Godot in a SessionStart hook** (`.claude/hooks/session-start.sh`, synchronous). A new phone session can run the tests at once, and it never races a half-finished install.
- **"Protect main" is deferred.** Branch protection on a private repo needs a paid GitHub plan, and spending is Jack's call. Until then, nothing merges to `main` until CI is green on its branch.

## Phase 1: Core loop prototype (2026-10-27)

### Content (branch `phase-1/content`)

- **A sixth autoload, `Content`, loads all game data in `_init`.** It's ready before any other autoload, and a data mistake becomes a boot error, which fails the boot check.
- **Seeded streams moved into a plain `RngStreams` class; the `Rng` autoload wraps one.** The balance sim and tests make their own streams, so they never shift the game's sequence.
- **Data files are checked by real JSON Schema files (a supported subset) in `data/schemas/`.** Editors already understand the format, so content can be edited with autocomplete and errors.
- **The checker is our own ~150 lines of GDScript, not a library.** No third-party code to license, and it reports errors as "items/toys.json[0].weight: expected integer, got string".
- **Items are one JSON file per category.** 300 items in one file would be unreadable; a folder of category files stays small.
- **Display text is keyed from ids (`ITEM_<ID>`, `ITEM_<ID>_DESC`, ...), not stored in the data.** Content stays translatable without a second name field, and a test catches a missing translation.
- **All four `unsafe_*` warnings are compile errors, with `JsonValue` for untyped data.** Warnings never show in CI logs, so only errors actually enforce "static types everywhere".
- **Tests run through `tools/gut.sh`, which fails on any script that didn't compile.** GUT skips a test file it can't load and still reports success; that happened on this branch and would have hidden two test files.
- **`Weighted.pick` walks keys in alphabetical order of their text.** Sorting StringNames compares memory addresses, so picks would change between runs.
- **Systems get `core/` (shared helpers) and `content/` (definitions, loader) folders** beside the plan's auction/loot/hauling/services/shop/customers/economy.
- **Phase 1 tuning numbers are a first pass, all in data:** $600 starting cash, $150 weekly rent, zone 1 openers at 30% of contents value, a 400 lb / 8-slot hatchback, 4 shelves of 3 slots. The balance sim (branch 1.5) checks them against the plan's targets.
