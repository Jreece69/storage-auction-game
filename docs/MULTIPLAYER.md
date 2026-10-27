# Crew co-op: multiplayer design

Jack's scope change, 2026-10-27: the game becomes co-op for 1 to 4 players,
online, built so friends can each do their own thing and still get the classic
friendslop chaos together. Where `DESIGN.md` says single-player, no multiplayer
or no walking character, this document wins. Everything else in the plan
stands.

## The short version

**You and up to three friends run one junk business as a crew.** One bank
account, one shop, one van. Every morning you go to the auction yard together,
and every afternoon you split up to run the shop.

The laughs come from three places, and this game has a natural version of each:

1. **Talking under pressure.** At the peek, every crew member sees a
   *different* third of the locker, so you have to shout what you saw ("there's
   a clock!" "that's a ceramic rooster, you idiot"). Then everyone bids with
   their own paddle from one shared bank, which means you can, and will,
   accidentally bid against your own friend and drive up your own price. The
   game logs it as friendly fire.
2. **Physical chaos.** Loot is carried to the van by hand. Heavy things slow you
   down, the arcade cabinet needs two people, and anything you drop or throw can
   break. That's the "Moving Out" energy, with real stakes, because a broken
   item sells for a third.
3. **Blame and bragging.** The end of each day hands out crew awards: Best
   Find, Big Spender, Silver Tongue (best haggle), Butterfingers (most items
   broken), Friendly Fire (most times you outbid your own crew).

**Doing your own thing** comes from the day splitting into jobs that run at the
same time once you have a crew: one person bids while another reads a rival's
tells, someone loads the van while someone else stays to scrap the junk, one
haggles with a customer while another restocks shelves or cleans items in the
workshop. Bigger crews get more customers and more lockers, so there's always
something for everyone.

**Solo still works**, as a crew of one, with the same rules.

**Where this sits against the competition:** Storage Hunter Simulator
($24.99) already has co-op, as a slow, realistic sim. Ours is the opposite
lane, the one `DESIGN.md` picked: fast days, auctions that are a read of
your rivals, loud jackpots, at a lower price. Co-op adds a group of friends
yelling over the same locker. The pillars stand; "one more locker" now also
means one more day with the crew.

## What's already built for this

These went in on 2026-10-27 (branch `phase-1/crew-rules`), before any screens
were built, so nothing has to be redone later:

- The rules run a **crew of 1 to 4** (seats p1, the host, to p4) with **one
  shared bank**.
- **Every member has their own bidding paddle.** Crewmates can outbid each
  other; it raises what the crew pays and is counted as friendly fire.
- **Each seat peeks a different random third** of every locker. Four peek sets
  are always rolled, so a seed gives the same lockers whatever the crew size.
- **Wins, spending, sales and finds are credited to whoever made them**
  (`MemberLedger`), which is what the end-of-day awards will read.
- All randomness and every rule already lives in plain, deterministic code
  (`RunController` and the systems), which is exactly what a host needs to run
  the game for everyone.

Proven the same day: two headless copies of Godot 4.7.2 connected over ENet on
one machine, a client pressed its paddle (an RPC asking to bid $105 as p2), and
the host applied it and broadcast it to both. So the networking approach below
works, and multiplayer tests can run automatically in CI.

## A co-op day, beat by beat

| Beat | Together or apart | What happens |
|---|---|---|
| Morning: pick a zone | Together | The crew votes on the map; the host confirms. One shared drive. |
| Peek | Together | Each member sees a different third of the locker. Ping an item to mark it for the crew; quick-chat lines for anyone without a mic. |
| Bidding | Together | Everyone has a paddle, one bank. Rivals react to any crew bid. One player jump-bids to scare the rookie while another stays quiet. Stare down (Phase 3) shows the staring player a rival's tell, and only them, so they have to report it. |
| Reveal | Together | Items pop out one at a time on everyone's screen. Big sting on a jackpot. |
| Haul | Together, then apart | Carry everything to the van by hand. Weight slows the carrier; very heavy items need two people (or a slow hand truck when solo). Drops and throws can break things. The facility closes soon, so it's a race. |
| Afternoon | Apart | The shop opens. Customers go to whoever greets them, so several haggles can run at once. Others restock, reprice, or clean and repair in the workshop (Phase 3). |
| Chaos events | Whoever's nearest | Phase 5 content: a shoplifter bolts for the door, a rival tries to lowball your shelf, a storm floods a locker. |
| Evening | Together | The day's summary plus the crew awards, then the next day. |

### What's shared and what's personal

- **Shared:** the bank, shop, van, inventory, net worth, zone unlocks, and the
  save (it lives on the host's machine).
- **Personal:** your character's look (colour and hat), your stats and awards,
  and from Phase 5 your skill levels (appraisal, haggling, intimidation), which
  grow with what *you* do. That gives natural roles: the haggler, the
  appraiser, the bidder.

### Crew size scaling (all in data)

Bigger crews get more to do, not an easier game: more customers per afternoon,
an extra locker or two per morning, more two-person items, and rivals with
slightly bigger budgets (a crew comparing notes sees more of every locker).
These become an `economy.json` block in Phase 2 so balancing stays a data
change.

## How the networking works

**One player hosts, up to three join.** The host's game is the referee: it runs
the real rules (the `RunController` and every system) and holds the only dice.
Everyone else sends requests ("I bid", "I pick up the lamp", "I counter at $70")
and receives what actually happened. Because clients never roll dice or apply
rules themselves, they can't drift out of sync.

| Thing | Who decides | How it travels |
|---|---|---|
| Bank, lockers, inventory, shop, customers | Host | Event messages, plus a full snapshot when someone joins (`RunState.to_dict()` already exists) |
| The auction | Host (owns the clock) | The `Auction` already reports plain events (bid, call, fold, sold): the host broadcasts them as they are |
| A player's own movement (Phase 3) | That player | Godot's `MultiplayerSynchronizer`, so moving feels instant |
| Picking up, carrying, dropping, breaking (Phase 3) | Host | Carried items ride on the carrier (no physics while carried); dropped and thrown items are simulated on the host and smoothed on clients |

**Transport has one seam, two implementations:**

- **ENet** (built into Godot): LAN and direct IP. Used for development, CI
  tests, and playtests with friends before the game is on Steam.
- **Steam** (GodotSteam's multiplayer peer): the host creates a Steam lobby,
  friends join from the Steam overlay, and traffic is relayed by Steam, so
  nobody forwards ports. GodotSteam 4.20 supports Godot 4.7.

The game code above the seam is the same for both.

**Joining and leaving:** players join at the start of a day (or watch until
the next one starts). If a player drops, whatever they were carrying drops with
them. If the host drops, the session ends and everyone returns to the title;
since the game saves at the start of each day, the most anyone loses is one
day. No host migration in v1.

**Fair last-second bids:** the host's clock decides, with a short grace window
(around 150 ms) for a bid that a client sent just before the hammer.

**Voice:** in Phase 4, Steam Voice for the whole crew, optionally positional in
the 3D spaces. Until then, friends use Discord or Steam chat, and the game has
pings and quick-chat.

**Steam Remote Play Together:** it streams a *local* multiplayer game to
friends who don't own it. Our co-op is native online, so it isn't needed; if
local shared-screen co-op is ever added, it comes for free.

## Testing

- **Rules:** unit tests already cover the crew (shared bank, friendly fire,
  per-seat peek, credit to the right member).
- **Netcode:** automated tests that start a headless host and one to three
  headless bot clients on one machine, play a scripted day, and check every
  peer ends with the same state. The 2026-10-27 spike shows this works in this
  environment.
- **Soak:** a 2-hour, 4-player session without desyncs or crashes before
  launch (Phase 6).
- **Playtests:** Jack and friends from CI builds over ENet. Until Steam relay
  arrives, the host needs a forwarded port or a free LAN-over-internet tool such
  as Tailscale or ZeroTier.

## Revised roadmap

Co-op slots in as one new phase; the plan's later phases shift up by one and
each gains its co-op part. Phase 1 is unchanged.

| Phase | What's in it | Gate (done when) |
|---|---|---|
| **1 Core loop prototype** | As planned, single-player graybox, on crew-ready rules | A full day plays start to finish, and Jack has played the CI build |
| **2 Co-op foundation (new)** | Lobby (host, or join by IP over ENet); 2 to 4 players through the graybox day: zone vote, per-seat peek, a paddle each, shared haul, parallel shop customers, end-of-day awards; automated multi-client tests in CI | Jack and at least one friend play a full day online, and CI runs a host plus bot clients through a day |
| **3 Vertical slice** (was 2) | The original Phase 2 plus the shared 3D dioramas: yard, van and shop with player avatars (fixed camera per location, gamepad-first, Steam Deck friendly), carrying with two-person lifts and breakage, rival tells and stare down, jackpot reveal, workshop, art and audio pass, tutorial, controller support at 1280×800 | 2 zones work, a first-timer finishes the tutorial unaided, 60 fps, and a 4-player day runs smoothly online |
| **4 Steam setup and demo** (was 3) | The original Phase 3 plus Steam lobbies, friend invites, relay networking and Steam Voice. A co-op demo (friend groups and streamers are how this genre spreads) | Coming Soon page live; the demo passes a clean install test solo and in a 4-player Steam lobby |
| **5 Content to v1.0** (was 4) | The original Phase 4 plus crew-size balancing, chaos events, the full award set, per-player skills | A tester finishes the main progression in 8 to 12 hours, and a 2-hour soak runs with no crash |
| **6 Polish and launch** (was 5) | The original Phase 5 plus a 4-player netcode soak | Launch |

Jack still starts the Steamworks signup during the vertical slice (now Phase
3), for the same reason: Valve's paperwork and waiting periods take over a month.

**Still out of scope:** free-roam driving (travel stays on the map screen),
host migration, cross-play beyond Steam, crews above 4, and a competitive
player-versus-player mode (possible later as "rival shops").

## The honest cost

This is the biggest addition to the plan. It adds roughly one phase of work
(Phase 2) and makes Phase 3 bigger (avatars and physical carrying instead of
menus). The main technical risks, and what keeps them small:

| Risk | Mitigation |
|---|---|
| Physics over the network gets out of sync | The host owns all item physics; carried items attach to the carrier instead of simulating |
| GodotSteam's multiplayer peer may need its own engine build rather than the add-on version (its docs say "only available in the main GodotSteam branches") | Check at the start of Phase 4. If so, export with GodotSteam's prebuilt engine, or write a small Steam transport on the add-on's messaging API behind the same seam |
| Every feature now has to work for 1 to 4 players | Rules are already crew-aware; automated multi-client tests run in CI from Phase 2 on |
| Balance differs by crew size | Scaling lives in data; the balance sim (Phase 1) gains crew sizes in Phase 2 |

## Decisions still reserved for Jack

- **Price.** Co-op "friendslop" games (Lethal Company, R.E.P.O., PEAK) are
  usually priced under $10 to $15, cheap enough that a whole group of friends
  buys in. The plan's earlier suggestion of $9.99 to $14.99 fits that. Needed
  by Phase 4.
- **Making anything public**, including a co-op demo or playtest builds shared
  outside the crew.
- **The title**, by Phase 4 (names that sound good said out loud in a group
  call help this genre).
