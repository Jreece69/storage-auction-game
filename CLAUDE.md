# Storage Auction Game — project brain

An original single-player storage-auction tycoon for PC, sold on Steam (Windows
first, Steam Deck Verified as a goal). The player wins lockers at auction,
hauls and appraises the contents, sells from their own shop, and grows from a
junkyard hustler into a top dealer. The hook: **every auction is a poker
hand**. Rival bidders have personalities, budgets and visible tells, so
winning is a read, not a timing bar.

**The full plan is [`docs/DESIGN.md`](docs/DESIGN.md)** (copied from Jack's PDF
in `docs/original/`). Read it before starting a phase. This file is the
summary, the current status, and the conventions every session follows.

Owner: **Jack**. Not technical, often on his phone. Explain plainly, keep his
steps to a minimum, and decide everything that isn't reserved for him.

## Status

| Phase | State |
|---|---|
| 0 Setup | **Done 2026-10-27.** CI green on `main` (25 tests, boot check, Windows export); boots to the title screen |
| 1 Core loop prototype (graybox) | **Next** |
| 2 Vertical slice | Not started. Jack starts the Steamworks signup during this phase |
| 3 Steam setup and demo | Not started |
| 4 Content to v1.0 | Not started |
| 5 Polish and launch | Not started |

Update this table when a phase closes, then post a short status to Jack:
what works, what's next, any blocker.

**Phase 1 checklist** (gate: a full day plays start to finish with
placeholder art, and Jack has played a Windows build from the CI artifacts):
data schemas plus 30 items, 3 locker themes, 1 zone, 3 rivals (Rookie, Shark,
Collector); auction logic with unit tests (rival max bid, countdown reset,
budgets), then a graybox auction scene; loot roll and a basic reveal; haul
with a capacity check, shop with 4 shelves, one customer type, simple offer
and counter; day loop, end-of-day summary, save and load; first balance sim
(a bot plays 30 in-game days and reports cash over time).

## Jack's working rules

- **Decide reversible things yourself.** Code structure, names, tuning numbers
  and tool choices are yours. Log each real decision in
  [`docs/DECISIONS.md`](docs/DECISIONS.md) with one line of why.
- **Ask Jack only about the reserved decisions** (below). How to ask: one
  message with the decision, 2 or 3 options and a recommendation. While
  waiting, keep building whatever doesn't depend on the answer.
- **Finish each phase cleanly:** the game runs, tests pass, work is committed
  and pushed, then a short status.
- **Commit small and often.** One feature per branch; merge to `main` only
  when CI is green on that branch.
- **Copy nothing from the Roblox game** (Storage Hunters: Open World): no
  code, art, sounds, UI, item names, zone names, modifier names or text.
  Mechanics only. Never "Storage Hunter(s)" or "Storage Wars" in our title.
  No real brands, logos or celebrity names on items; invent or parody them.
- **Content lives in data files, not code,** so balancing never needs a code
  change.
- **If a step in the plan proves wrong or impossible,** take the closest
  alternative, log it in `DECISIONS.md`, and keep going.

### Reserved for Jack (ask first)

| Decision | Needed by | Default until he decides |
|---|---|---|
| Game title | Phase 3, before the store page | Working title; propose 5 names with Steam, web and USPTO conflict checks |
| Price | Phase 3 | None (plan suggests $9.99 to $14.99) |
| Any spending: assets, commissions, tools, Steam fee, GitHub plan | Before each purchase | Free CC0 assets only |
| Making anything public: repo, store page, demo, posts | Before it happens | Everything private |
| Dates for Coming Soon, demo and launch | Phase 3 | None |
| Selling as an individual or a company | Steamworks signup | None |
| Changing a pillar or cutting a v1.0 feature | When it comes up | Keep the plan |

## Run and test

All commands run from the repo root. In a cloud session the SessionStart hook
installs the pinned Godot automatically.

```bash
tools/test.sh            # import + every GUT test + boot check (what CI runs)
tools/lint.sh            # quick check: every script compiles, scenes load, text uses keys
tools/export_windows.sh  # Windows build into build/windows/ (downloads templates once)
tools/install_godot.sh   # installs the pinned Godot if needed, prints its path

# One test file, or tests whose name contains some text:
tools/gut.sh -gselect=test_rng
tools/gut.sh -gunit_test_name=json
```

Always run tests through `tools/gut.sh` (the other scripts do). GUT on its
own skips a test file that fails to compile and still reports success;
`gut.sh` fails the run instead.

On Jack's Windows PC: open `game/project.godot` in Godot 4.7.2. The GUT panel
at the bottom of the editor runs the tests.

**CI** (`.github/workflows/ci.yml`) runs on every push to any branch:
tests and boot check, then a Windows export. Pushes to `main` also upload the
build as the `windows-build` artifact (the newest three are kept, because the
free plan has 500 MB of artifact storage). Jack downloads it from the run's
page under Actions.

## Pinned versions

- **Godot 4.7.2 stable.** `tools/GODOT_VERSION` is the single source; CI and
  every script read it. To upgrade: change that file, run `tools/test.sh` and
  the export, then update this line and `DECISIONS.md`.
- **GUT 9.7.1** (its release line targets Godot 4.7.x), vendored in
  `game/addons/gut/`. Upgrade by replacing the folder from the matching GUT
  release.
- **GitHub Actions:** `actions/checkout@v7`, `actions/cache@v6`,
  `actions/upload-artifact@v7`.

## Code conventions

- **Typed GDScript everywhere.** `untyped_declaration` and the four `unsafe_*`
  warnings are compile errors (add-ons are exempt). Untyped data (parsed
  JSON, `Dictionary` values) goes through `JsonValue` (`as_int`, `as_float`,
  `as_name`, ...) or into a typed variable first: `int(variant)` and passing a
  Variant to a typed parameter don't compile. GUT asserts count as typed
  calls, so assert on typed values (`var picked: StringName = ...`).
  Godot style guide: tabs, `snake_case` files, functions and variables,
  `PascalCase` classes and nodes.
- **Layout:**
  - `game/scenes/<area>/`: each `.tscn` with its script beside it. Scenes
    only display state and forward input.
  - `game/scripts/autoload/`: the six singletons `Content`, `EventBus`, `Rng`,
    `Settings`, `GameState`, `SaveManager`. Autoload scripts have no
    `class_name` (it would clash with the singleton name).
  - `game/scripts/systems/<area>/`: all game rules, as plain `RefCounted`
    classes with `class_name` and no node or scene dependencies, so they run
    and test headless. `core/` holds shared helpers (`RngStreams`, `Weighted`,
    `Money`, `JsonValue`); `content/` holds the content definitions and the
    `Catalog` loader.
  - `game/data/`: JSON content, its schemas, and `translations/strings.csv`.
- **Content:** every item, theme, zone, rival, customer type and vehicle is a
  JSON entry in `game/data/` (items are one file per category in
  `data/items/`), checked against `data/schemas/<file>.schema.json` (a subset
  of JSON Schema) and then cross-checked by `Catalog` (theme categories have
  items, zone rivals exist, ranges run low to high, and so on). The `Content`
  autoload loads it all at startup; any problem is a boot error. Systems take
  the `Catalog` or the definitions they need as arguments, never the
  autoload. Display text is keyed from the id: `ITEM_<ID>` and
  `ITEM_<ID>_DESC`, `THEME_<ID>`, `ZONE_<ID>`, `RIVAL_<ID>`,
  `PERSONALITY_<P>`, `CUSTOMER_<ID>`, `VEHICLE_<ID>`, `CATEGORY_<C>`,
  `RARITY_<R>`, `CONDITION_<C>`. `test_catalog.gd` fails if any is missing.
- **Systems talk through `EventBus` signals** with plain-data arguments, never
  through direct references to each other.
- **Randomness only through seeded streams.** The game uses
  `Rng.stream(&"system")`; systems take a `RandomNumberGenerator` (or an
  `RngStreams`) as an argument so tests and the balance sim can pass their
  own. Never the global `randi()`, `randf()`, `randomize()`,
  `Array.shuffle()` or `Array.pick_random()`; they use Godot's global
  generator and break replays. Weighted choices go through `Weighted.pick`,
  which walks keys in alphabetical order (sorting StringNames directly
  compares memory addresses, which differ from run to run).
- **Money is whole dollars in `int`.**
- **Saves:** `SaveManager` writes JSON to `user://saves/` with a `version`.
  When the format changes, bump `SAVE_VERSION` and add a step in
  `_migrate_step`. Store 64-bit numbers (seeds, generator state) as strings:
  JSON numbers lose precision above 2^53.
- **Text:** every player-facing string is a key in
  `game/data/translations/strings.csv`. Labels and buttons hold the key (Godot
  translates it); scripts call `tr("KEY")`. A test fails if a scene has raw
  English in a label or button. Godot imports every `.csv` in `game/` as a
  translation table, so data tables must be JSON.
- **Input:** every menu works with mouse, keyboard and gamepad. Call
  `grab_focus()` on the first control in `_ready()`. Readable at 1280×800.
- **Tests (GUT):** `game/tests/unit/` for systems, `game/tests/scenes/` for
  scenes. Files are `test_*.gd` and `extends GutTest`. GUT fails a test on any
  engine error or `push_error`; when an error is the expected outcome, assert
  it with `assert_push_error("text")`. `test_project_integrity.gd` checks that
  every script compiles, every scene instantiates, and scene text uses keys.
- **Exports** leave out `tests/` and `addons/gut/` (`export_presets.cfg`). The
  Windows build is a single `.exe` with the game packed inside.

## Assets and licensing

- Every third-party asset gets a line in `CREDITS.md` (name, source URL,
  license) and its license file in `game/assets/third_party/<source>/`.
- Commercial-use licenses only: CC0, CC-BY with credit, or paid licenses that
  say so. Never NC, "personal use only" or unclear terms.
- AI-generated content that ships goes in `docs/AI_CONTENT.md` so Jack can
  fill in Steam's content survey.
- `.glb`, `.png`, `.ogg` and `.wav` go through Git LFS (`.gitattributes`).
  The tiny icons inside `game/addons/` are exempt so a plain clone works.
  CI caches LFS files so it doesn't burn the account's LFS bandwidth.

## Known gaps

- **`main` is not protected.** GitHub's branch protection on a private repo
  needs a paid plan (Pro or Team), which is Jack's call. Until then, the rule
  is followed by hand: merge to `main` only after CI is green on the branch.
- The placeholder icon (`game/icon.svg`) and UI theme
  (`game/assets/ui/theme.tres`) are replaced in Phase 2.
