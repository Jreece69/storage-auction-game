class_name AuctionRules
extends Resource
## How auctions run, from the "auction" block of game/data/economy.json.

## Seconds to look through the open door before bidding starts.
@export var peek_seconds: float = 20.0
## Share of a locker's items visible during the peek; the rest are silhouettes.
@export var visible_share: float = 0.34
## "Going once, going twice, sold": seconds after each bid before the hammer.
@export var countdown_seconds: float = 5.0
## The minimum raise is this share of the current price, rounded up nicely.
@export var raise_share: float = 0.05
## Never raise by less than this many dollars.
@export var min_raise: int = 5
## A jump bid adds this share of the current price...
@export var jump_share: float = 0.25
## ...and at least this many minimum raises.
@export var jump_min_raises: int = 3
## The auctioneer never opens below this.
@export var min_opening: int = 10


## The smallest raise allowed over [param price]: about raise_share of it,
## rounded to a nice amount, and never under min_raise.
func raise_amount(price: int) -> int:
	return maxi(min_raise, Money.round_nice(price * raise_share))


## How much a jump bid adds over [param price].
func jump_amount(price: int) -> int:
	return maxi(raise_amount(price) * jump_min_raises, Money.round_nice(price * jump_share))


static func from_dict(data: Dictionary) -> AuctionRules:
	var rules := AuctionRules.new()
	rules.peek_seconds = JsonValue.as_float(data["peek_seconds"])
	rules.visible_share = JsonValue.as_float(data["visible_share"])
	rules.countdown_seconds = JsonValue.as_float(data["countdown_seconds"])
	rules.raise_share = JsonValue.as_float(data["raise_share"])
	rules.min_raise = JsonValue.as_int(data["min_raise"])
	rules.jump_share = JsonValue.as_float(data["jump_share"])
	rules.jump_min_raises = JsonValue.as_int(data["jump_min_raises"])
	rules.min_opening = JsonValue.as_int(data["min_opening"])
	return rules
