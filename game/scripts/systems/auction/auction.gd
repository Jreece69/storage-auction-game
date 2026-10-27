class_name Auction
extends RefCounted
## One locker's open ascending auction, run on game time so the same logic
## serves the real-time scene, the tests and the balance sim.
##
## The auctioneer opens at the opening price. Every bid restarts the
## countdown: "going once" at two thirds, "going twice" at one third, then
## sold. Each rival answers a new high bid after their reaction time, if the
## next bid is within their max; otherwise they drop out. A jump bid can
## scare some rivals off on the spot.
##
## Calls return what happened, in order, as plain dictionaries for the scene:
##   {"type": "bid", "bidder": id, "amount": int, "jump": bool}
##   {"type": "call", "stage": 1 or 2}      going once, going twice
##   {"type": "fold", "bidder": id}
##   {"type": "sold", "bidder": id, "amount": int}
##   {"type": "unsold"}
## The player's id is [constant PLAYER].

enum State { OPEN, SOLD, UNSOLD }

const PLAYER: StringName = &"player"
const NOBODY: StringName = &""
## Two events closer together than this count as simultaneous.
const EPSILON: float = 0.000001
## A safety stop for run_to_end(); real auctions end long before.
const MAX_STEPS: int = 100000

var state: State = State.OPEN
var opening_price: int
## The current high bid. 0 until someone bids.
var price: int = 0
var high_bidder: StringName = NOBODY
## Seconds until the hammer falls.
var countdown: float
var bidders: Array[RivalBidder] = []
## The most the player can spend; their bids never go above it.
var player_cash: int
var player_out: bool = false
var bid_count: int = 0

var _rules: AuctionRules
var _rng: RandomNumberGenerator
var _calls_made: int = 0


func _init(rules: AuctionRules, p_opening_price: int, p_bidders: Array[RivalBidder], p_player_cash: int, rng: RandomNumberGenerator) -> void:
	_rules = rules
	_rng = rng
	opening_price = p_opening_price
	bidders = p_bidders
	player_cash = p_player_cash
	countdown = rules.countdown_seconds
	_schedule_rivals()


func is_open() -> bool:
	return state == State.OPEN


## Who won: [constant PLAYER], a rival's id, or [constant NOBODY].
func winner() -> StringName:
	return high_bidder if state == State.SOLD else NOBODY


## The smallest bid the auctioneer will take right now.
func next_bid() -> int:
	if high_bidder == NOBODY:
		return opening_price
	return price + _rules.raise_amount(price)


## What a jump bid comes to right now.
func jump_bid() -> int:
	var base := opening_price if high_bidder == NOBODY else price
	return base + _rules.jump_amount(base)


func can_player_bid(amount: int) -> bool:
	return is_open() and not player_out and high_bidder != PLAYER and amount <= player_cash


func player_raise() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var amount := next_bid()
	if can_player_bid(amount):
		_place_bid(PLAYER, amount, false, events)
	return events


## A big raise meant to scare rivals off.
func player_jump() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var amount := jump_bid()
	if can_player_bid(amount):
		_place_bid(PLAYER, amount, true, events)
	return events


## The player drops out of this auction; the rivals settle it between them.
func player_pass() -> void:
	player_out = true


## Runs [param delta] seconds of auction time.
func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var remaining := delta
	var steps := 0
	while is_open() and remaining > 0.0 and steps < MAX_STEPS:
		steps += 1
		var step := minf(remaining, _time_to_next_call())
		var due := _first_rival_due()
		if due != null and due.timer < step:
			step = due.timer
		_tick(step)
		remaining -= step
		if due != null and due.timer <= EPSILON:
			_rival_answers(due, events)
		elif countdown <= EPSILON:
			_hammer(events)
		elif _calls_made < 2 and countdown <= _call_time(_calls_made + 1) + EPSILON:
			_calls_made += 1
			events.append({"type": "call", "stage": _calls_made})
	return events


## Runs the auction until the hammer falls, for when the player has passed
## or for the balance sim.
func run_to_end() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var steps := 0
	while is_open() and steps < MAX_STEPS:
		steps += 1
		events.append_array(advance(_rules.countdown_seconds))
	return events


func _place_bid(who: StringName, amount: int, jump: bool, events: Array[Dictionary]) -> void:
	price = amount
	high_bidder = who
	bid_count += 1
	countdown = _rules.countdown_seconds
	_calls_made = 0
	events.append({"type": "bid", "bidder": who, "amount": amount, "jump": jump})
	if jump:
		_scare_rivals(who, events)
	_schedule_rivals()


func _scare_rivals(jumper: StringName, events: Array[Dictionary]) -> void:
	for bidder in bidders:
		if bidder.folded or bidder.id == jumper:
			continue
		if _rng.randf() < bidder.def.jump_fold_chance:
			bidder.folded = true
			bidder.timer = -1.0
			events.append({"type": "fold", "bidder": bidder.id})


## Every rival still in, except the high bidder, starts thinking it over.
func _schedule_rivals() -> void:
	for bidder in bidders:
		if bidder.folded or bidder.id == high_bidder:
			bidder.timer = -1.0
		else:
			bidder.timer = _rng.randf_range(bidder.def.reaction_min, bidder.def.reaction_max)


func _rival_answers(bidder: RivalBidder, events: Array[Dictionary]) -> void:
	bidder.timer = -1.0
	if bidder.folded or bidder.id == high_bidder:
		return
	var amount := next_bid()
	if amount > bidder.max_bid:
		bidder.folded = true
		events.append({"type": "fold", "bidder": bidder.id})
		return
	_place_bid(bidder.id, amount, false, events)


func _hammer(events: Array[Dictionary]) -> void:
	if high_bidder == NOBODY:
		state = State.UNSOLD
		events.append({"type": "unsold"})
	else:
		state = State.SOLD
		events.append({"type": "sold", "bidder": high_bidder, "amount": price})


func _tick(seconds: float) -> void:
	countdown -= seconds
	for bidder in bidders:
		if bidder.timer >= 0.0:
			bidder.timer = maxf(bidder.timer - seconds, 0.0)


func _first_rival_due() -> RivalBidder:
	var first: RivalBidder = null
	for bidder in bidders:
		if bidder.timer >= 0.0 and (first == null or bidder.timer < first.timer):
			first = bidder
	return first


## Seconds until the next "going once/twice", or until the hammer.
func _time_to_next_call() -> float:
	if _calls_made < 2:
		return maxf(countdown - _call_time(_calls_made + 1), 0.0)
	return maxf(countdown, 0.0)


## Countdown remaining when call [param stage] is made: 2/3 then 1/3.
func _call_time(stage: int) -> float:
	return _rules.countdown_seconds * (3 - stage) / 3.0
