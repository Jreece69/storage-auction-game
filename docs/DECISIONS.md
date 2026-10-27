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

### Loot and auction logic (branch `phase-1/auction`)

- **The auction runs on game time as a pure state machine (`advance(seconds)` returns events).** The real-time scene, the tests and the balance sim all drive the same code; tests are exact, not timing-dependent.
- **A rival who can't afford the next bid drops out when their reaction timer fires, not instantly.** The fold reads as a decision, and it's the hook for Phase 2's tells.
- **When a rival's bid and the hammer land at the same instant, the bid counts.** Last-second bids are part of the drama.
- **The minimum raise is about 5% rounded to the nearest nice amount, never under $5.** Rounding up made the raise at $105 come to $10 (10%), not about 5%.
- **A jump bid adds a quarter of the price, and at least three minimum raises.** Big enough to read as aggressive at every price.
- **Rivals' max bids are fixed per locker (estimate × appetite, capped by remaining budget).** Simple to reason about and to test; Phase 2's memory and grudges adjust them.
- **The collector's bias scales with the share of the locker's value in their category.** A single toy in a garage locker shouldn't make them go wild.
- **Items keep unique ids for the whole save (`UidCounter`).** Haul, shelves, sales and the ledger can all refer to one item safely.
- **Unit tests use small fixed test content (`tests/helpers/fixture.gd`), not the real data.** Rebalancing the real numbers never breaks a test; separate tests check the real data loads and rolls sensibly.

### Haul, shop, customers and the day loop (branch `phase-1/day-loop`)

- **The game saves at the start of each day.** A save is the run and the random streams as the day began, so loading replays the same lockers; progress inside a day isn't saved. Simple, and nothing can be save-scummed mid-auction.
- **`RunController` runs the day as plain code; the `GameState` autoload holds it and forwards its signals to `EventBus`.** The balance sim drives the same controller with no scenes at all.
- **A locker the player skips is still auctioned, among the rivals.** Their budgets drain the same way whether or not the player bids, so "let the rookie overpay, then snipe the next one" works.
- **Leftovers that don't fit the vehicle are scrapped by weight, along with the junk.** The plan's alternative, a second trip that costs time, waits for Phase 2's day clock.
- **The scrap job is offered only before any bidding, when cash is under $100 (in data).** It's the plan's "never a game over" safety net, not a farm.
- **Cash can go negative (rent can push it under); bidding just isn't possible until it recovers.** No game over, as the plan requires; loans come later.
- **Customers arrive one at a time and pick from what's on the shelves right then.** Two customers can never buy the same item.
- **A customer has a hidden limit; any counter within it is accepted, and each counter above it moves their offer halfway to the limit.** Two failed counters and the third sends them away (patience 2, in data). Plays like haggling without being guessable.
- **"Best find" counts everything in a won locker, even items left behind.** It's about what you found, not what fit in the car.
- **Save format version 2 (the whole run); version 1 saves migrate.** The first real use of the migration step, tested.

## Scope change by Jack: co-op multiplayer (2026-10-27)

Jack asked for the game to be multiplayer: a crew of 2 to 4 friends ("duo,
trio, quad"), online, where each player can do their own thing but the group
gets the classic friendslop laughs together. This reverses two of the plan's
scope cuts ("no multiplayer in v1.0" and "no walking character"). The full
design and the revised roadmap are in [`MULTIPLAYER.md`](MULTIPLAYER.md).

### Co-op-ready rules (branch `phase-1/crew-rules`)

- **The business belongs to a crew of one to four, seated p1 (the host) to p4, sharing one bank.** Solo is a crew of one, so there's one set of rules, not two.
- **Every crew member has their own bidding paddle, and crewmates can outbid each other.** It only raises what the crew pays, and it's logged as friendly fire: built-in comedy, and a stat for the end-of-day awards.
- **Each crew seat peeks a different random third of a locker.** A crew sees more by comparing notes, so talking is part of the auction.
- **Four peek sets are always rolled, whatever the crew size.** A seed gives the same lockers solo or in a crew of four.
- **Wins, spending, sales and finds are credited to the member who made them (`MemberLedger`).** End-of-day awards and blame need per-player numbers.
- **Crew composition isn't saved.** Friends come and go between sessions; the business and its bank carry on in the host's save.

### Graybox screens (branch `phase-1/screens`)

- **One app shell (`main.tscn`) shows one screen at a time; screens ask to move on with `Screens.go()` through EventBus.** Screens never load each other, so each can be tested alone.
- **The auction screen draws only what the auction reports (bid, call, fold, sold).** In co-op the same screen can draw the events the host broadcasts.
- **The peek shows item names and rarity, not condition or value.** Those come out at the reveal; the price guide and appraisal tools add more later.
- **Once the whole crew has passed, the rivals finish the auction at 4× speed.** Nobody wants to watch a locker they've given up on.
- **The reveal brings items out one at a time, about two a second, with a "Show it all" button.** A basic version of the jackpot moment; the loud one comes with the vertical slice.
- **The van starts loaded with the best value that fits; the player can change it.** One click for most lockers, full control when it matters.
- **Shelving puts an item on the first shelf with room, at the suggested price; tags move in the data's $5 steps.** The fewest presses that still let the player price things.
- **A counter-offer starts halfway between the customer's offer and the tag, and can't go above the tag.** A sensible default that's one press away.
- **Customers come one at a time.** Co-op adds several at once (see `MULTIPLAYER.md`).
- **The game writes the save when the shop closes and when the window closes.** Both write the start-of-day snapshot, so a crash or a quit costs at most the day in progress.
- **New game asks to be pressed twice when there's a save.** A new run replaces the old save, which shouldn't happen by accident.
- **Tests that save go through `tests/helpers/save_sandbox.gd`, which points saves at `user://gut_saves/`.** Running the tests on Jack's PC must never touch his real save.
- **Screen scripts have class names (`AuctionYard`, `ShopScreen`, ...).** Typed tests can drive them under the strict-typing rules.
- **`tools/screenshots.sh` plays day 1 on a virtual display and saves a screenshot of every screen.** Tests can't see layout; this lets a cloud session check it.

### Balance sim and the first tuning pass (branch `phase-1/balance-sim`)

- **The sim's bot is a game system (`BalanceBot`) driving `RunController`, not a copy of the rules.** It measures the real game, it's unit-tested, and it can become the bot client for co-op tests.
- **The sim compares three bots: a beginner, one that plays the rivals, and one that also minds its stock.** One bot can't tell a broken economy from a bad strategy.
- **The bot that plays the rivals reads the shark and jump-bids the rookie.** That's the plan's hook, and the read a player learns before tells exist.
- **Rivals keep the plan's model: they estimate from the true value with skill noise, and the opener reflects the true contents.** Tried peek-only rivals; it made bargains easy but made reading rivals worth less, and the plan gets its ×10 finds from value modifiers instead.
- **Tuning changes (bargain hunters pay 85% to 115% of market, cooler shark and collector, poorer rookie, hatchback space 10, rent $100, 8 customers a day).** The first sim had every bot losing money; the reasons for each are in `BALANCE.md`.
- **Locker return is measured as contents value ÷ price and as money returned ÷ spent, with and without unsold stock.** The plan's 1.2× to 1.6× target is ambiguous; all three are reported.
- **CI runs 20 seeds of the sim on every push and posts the report on the run's summary page.** The sim can't silently break, and anyone can see the numbers.
- **CI exports a `.pck` with the Windows preset and plays day 1 through it headless (`tools/export_smoke.sh`).** A file the export leaves out fails CI instead of the game on Jack's PC; proved by leaving out `rivals.json`.

## Phase 2: Co-op foundation (2026-10-27)

### The day as one shared flow (branch `phase-2/live-state`)

- **`DayFlow` runs the day: the stages (map, peek, bidding, result, reveal, haul, shop, summary), the clocks, the votes and the shop counters.** Online, one machine has to run all of that for everyone; before this, each screen ran its own piece.
- **Every move goes through `DayFlow.handle(member, command, args)`, and screens make the local player's moves with `GameState.act(command)`.** A move from another machine will be the same call, so networking only has to carry commands.
- **Moves that would cut a crewmate short wait for the whole crew: starting the bidding early, driving home, closing up.** Everything else (bids, the reveal, the next locker, the shop) goes through for whoever presses first, which keeps the day moving.
- **Each crew member has their own shop counter and customer; customers never pick up an item someone else's customer is holding.** Several players can haggle at once.
- **A bigger crew gets more customers: `crew_extra_customers` (4) per extra member, in the data.** More hands, more to do.
- **Everything live copies to plain data (`to_dict`/`from_dict` on lockers, the day, auctions, customers, counters, the flow), and `DayFlow.mirror()` builds another player's copy.** The host sends state, not instructions to replay, so copies can't drift. Rival max bids and customer limits stay on the host.
- **The app shell shows the screen for the day's stage.** Every player in a crew sees the same screen at the same time, and screens no longer move each other on.
- **The game saves when the day closes (`DayFlow.day_closed`), from `GameState`, not from a screen.** Only the host will save.

### The network session (branch `phase-2/session`)

- **`Session` (autoload) hosts or joins over ENet; the host's machine runs the real day and everyone else shows a copy.** The host is the referee, as `MULTIPLAYER.md` planned, so copies can't drift.
- **The host sends the run, today and the flow as three channels, only when they change, plus the clocks ten times a second while they run.** Small updates, and a copy's clocks tick on their own in between.
- **A joined player's move goes to the host as a command; their screen counts it as done and the host's next update shows the result.** No waiting on the network to press a button.
- **Seats go p2 to p4 in the order friends say hello; a fifth is turned away, as is a different game version.** Simple and fair.
- **Friends who join mid-day watch until the next day starts, then join the crew.** The crew only changes on the map, so a day's votes and counters never change shape under the players.
- **A player who drops out passes on the locker and lets their customer go; if the host drops out, the session ends for everyone.** No host migration in v1, as planned; the save is at most a day old.
- **The host only sends to players whose connection is fully up, one by one, and doesn't relay connection news between players.** Found by the co-op smoke test: two friends leaving at once made broadcasts to the half-gone one fail.
- **`tools/coop_smoke.sh` plays a co-op day with a host and up to three bot friends, each a separate copy of the game, over ENet on localhost, and checks they all agree.** CI runs it with a full crew of four on every push.
