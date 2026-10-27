# Balance

The tuning targets from the plan, how each one is measured, and a log of
balance passes. Every tuning number lives in `game/data/`, never in code.

## Targets

| Target | Value | Measured by | Status (2026-10-27) |
|---|---|---|---|
| First zone unlock | 15 to 20 minutes | Balance sim, then playtests | Zone 2 arrives with the vertical slice. Set its unlock from the net worth curve below: a decent player has about $800 by day 3 |
| Main progression | 8 to 12 hours, then endless play | Playtests (content phase) | Not measurable yet |
| Average locker return | 1.2× to 1.6× the price paid | Balance sim | Contents come to 1.27× to 1.30× of the price at market value. After haggling and what doesn't fit in the van, 1.16× to 1.20× comes back, counting unsold stock: at the low end, on purpose, until upgrades and better customers arrive |
| A ×10 or better find | About once every 30 lockers | Balance sim | Comes from value modifiers (Signed, Misprint and so on), which arrive with the vertical slice. None in Phase 1 by design |
| One bid, haul and sell cycle | 3 to 5 minutes, with travel and menus under about 30 seconds | Playtests | Jack's first playtest |

## Balance sim

```bash
tools/balance_sim.sh                         # 200 runs per bot, about a minute
tools/balance_sim.sh --seeds=50 --days=14    # quicker
tools/balance_sim.sh --out=build/report.md   # also write the report to a file
```

`BalanceBot` (`game/scripts/systems/sim/`) plays whole days through
`RunController`, the same rules the screens use. Each run has its own seed
(runs 1 to N), so any run replays exactly. CI runs 20 seeds on every push and
puts the report on the run's summary page.

The sim compares three bots:

- **Beginner:** estimates a locker from what it can see (the typical value of
  each visible kind, scaled up to the whole locker, plus the junk) and bids up
  to 60% of that.
- **Plays the rivals:** bids up to 75%, and reads the table the way a player
  learns to. While the shark (the accurate rival) is still bidding, the locker
  is worth at least the price over the most the shark pays; when the shark
  drops out, it's worth about that price over the shark's usual margin. Its
  first bid is a jump bid whenever the rookie is in, since he folds to one
  more than half the time.
- **Plays the rivals and minds its stock:** the same, but it sits the
  auctions out while 14 or more items are unsold. This is the "decent
  player" the tuning aims at.

Every bot hauls the best load that fits, prices everything at the suggested
price, takes any offer within 15% of the tag, and otherwise holds out for the
tag until the customer's last offer.

**What the columns mean.** *Contents value ÷ price* is the market value of
everything in the lockers won (junk as scrap) over what was paid, pooled over
all wins. *Sales and scrap ÷ spent* is the money that actually came back.
*Counting unsold stock* adds what was still unsold on the last day, at
market value. *Left behind* is the market value of items that didn't fit in
the van.

## Passes

### Pass 1 (2026-10-27): first sim, and the economy didn't work

The first run (200 seeds, the tuning from the content phase) showed every bot
losing money. The beginner bot ended day 30 with about $140 in every run and
needed scrap jobs in all of them. Three leaks, and what changed:

| Leak | Change | Why |
|---|---|---|
| Customers paid 65% to 100% of market value, so selling lost money on every item | `bargain_hunter` will pay 85% to 115% (was 65% to 100%), and opens lower, at 60% to 80% (was 65% to 85%) | Still a bargain hunter: they open low and haggle, but pay a fair price if you hold firm. Stingier and pricier buyers come with the other customer types |
| Rivals together bid close to full value, so wins had no margin | Shark bids up to 55% to 65% of his estimate (was 62% to 72%), collector 65% to 75% (was 75% to 85%, estimate noise 0.15 from 0.18), rookie 95% to 120% (was 100% to 125%) from a $300 to $600 budget (was $400 to $700) | A good read should buy at a discount. The rookie still overpays, but runs out of money sooner and folds to jump bids |
| The hatchback left 7% of every locker's value behind | Hatchback space 10 (was 8) | Leaving things behind should be a choice on big lockers, not a tax on every one |
| Weekly rent of $150 ate any profit | Rent $100 (was $150) | The starting shop is small; the plan has rent rise with shop size |
| Six customers a day couldn't sell a locker a day | 8 customers a day (was 6) | One won locker holds 5 to 9 items |

Results after the pass, 200 runs of 30 days each:

| Bot | Lockers won | Contents ÷ price | Returned, counting stock | Cash, day 30 | Net worth, day 30 | Runs that needed a scrap job |
|---|---|---|---|---|---|---|
| Beginner | 25% | 1.29× | 1.18× | $1,008 ($424 to $1,575) | cash plus about $90 of stock | 2 of 200 |
| Plays the rivals | 40% | 1.29× | 1.20× | $332 ($182 to $504) | cash plus $1,356 of unsold stock | 16 of 200 |
| Plays the rivals, minds its stock | 36% | 1.27× | 1.16× | $690 ($315 to $1,250) | $1,486 ($994 to $2,089) | 11 of 200 |

Ranges are the middle 80% of runs. The decent player's net worth by day:
$679 on day 1, $803 on day 3, $878 on day 7, $1,072 on day 14, $1,244 on
day 21, $1,486 on day 30.

What this says:

- **A beginner makes a living and a good player does better.** Scrap jobs
  are rare (2 to 16 runs in 200), and reading the rivals wins about half as
  many lockers again.
- **Selling is the limit, not buying.** A good player can win more than the
  shop can sell; the bot that buys everything ends the month cash-poor on a
  pile of stock. That's the opening the plan's shop upgrades (shelves, decor,
  an assistant) and better customer types fill.
- **Growth is steady but slow, about $30 a day.** Fine for one zone and no
  upgrades. Bigger zones and upgrades in the vertical slice should bend the
  curve upward.

Also tried and dropped: rivals and the auctioneer judging a locker from their
own peek instead of its true value. It made bargains and hidden jackpots
possible, but the plan has rivals know roughly what's inside, which makes
reading them worth something, and has the ×10 finds come from value
modifiers. The plan's model stays.

**Next pass:** with value modifiers and zone 2 (vertical slice). Check the ×10
rate, set zone 2's unlock from the curve above, and add customer types.
