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
## The human side is a crew of one to four (see Crew), each with their own
## paddle and one shared bank. Crewmates can outbid each other: it's allowed,
## it only raises what the crew pays, and it's flagged as friendly fire.
##
## Calls return what happened, in order, as plain dictionaries for the scene:
##   {"type": "bid", "bidder": id, "amount": int, "jump": bool,
##    "friendly_fire": bool}                 friendly fire: crew over crew
##   {"type": "call", "stage": 1 or 2}      going once, going twice
##   {"type": "fold", "bidder": id}
##   {"type": "sold", "bidder": id, "amount": int}
##   {"type": "unsold"}

enum State { OPEN, SOLD, UNSOLD }

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
## The crew members bidding here, in seat order.
var crew: Array[StringName] = []
## The crew's bank: no crew bid goes above it.
var crew_cash: int
## Crew members who have passed on this locker.
var crew_out: Array[StringName] = []
## How many times each crew member outbid a crewmate here.
var friendly_fire: Dictionary[StringName, int] = {}
var bid_count: int = 0

var _rules: AuctionRules
var _rng: RandomNumberGenerator
var _calls_made: int = 0


func _init(rules: AuctionRules, p_opening_price: int, p_bidders: Array[RivalBidder], p_crew: Array[StringName], p_crew_cash: int, rng: RandomNumberGenerator) -> void:
	_rules = rules
	_rng = rng
	opening_price = p_opening_price
	bidders = p_bidders
	crew = p_crew
	crew_cash = p_crew_cash
	countdown = rules.countdown_seconds
	_schedule_rivals()


func is_open() -> bool:
	return state == State.OPEN


func is_crew(bidder: StringName) -> bool:
	return crew.has(bidder)


## Who won: a crew member, a rival's id, or [constant NOBODY].
func winner() -> StringName:
	return high_bidder if state == State.SOLD else NOBODY


## Whether the crew won, whichever member held the last bid.
func crew_won() -> bool:
	return state == State.SOLD and is_crew(high_bidder)


## The smallest bid the auctioneer will take right now.
func next_bid() -> int:
	if high_bidder == NOBODY:
		return opening_price
	return price + _rules.raise_amount(price)


## What a jump bid comes to right now.
func jump_bid() -> int:
	var base := opening_price if high_bidder == NOBODY else price
	return base + _rules.jump_amount(base)


## Whether [param member] may bid [param amount] now. Nobody can raise their
## own bid, but anyone can raise a crewmate's.
func can_bid(member: StringName, amount: int) -> bool:
	return is_open() and is_crew(member) and not crew_out.has(member) and high_bidder != member and amount <= crew_cash


func raise(member: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var amount := next_bid()
	if can_bid(member, amount):
		_place_bid(member, amount, false, events)
	return events


## A big raise meant to scare rivals off.
func jump(member: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var amount := jump_bid()
	if can_bid(member, amount):
		_place_bid(member, amount, true, events)
	return events


## [param member] stops bidding on this locker. Holding the high bid, they
## can still win it at that price.
func pass_out(member: StringName) -> void:
	if is_crew(member) and not crew_out.has(member):
		crew_out.append(member)


## Every crew member has passed; the rivals settle it between them.
func all_crew_out() -> bool:
	return crew_out.size() >= crew.size()


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


## Runs the auction until the hammer falls, for when the crew has passed or
## for the balance sim.
func run_to_end() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var steps := 0
	while is_open() and steps < MAX_STEPS:
		steps += 1
		events.append_array(advance(_rules.countdown_seconds))
	return events


## The auction as plain data, for showing it on other players' screens. The
## rivals' estimates and max bids stay on the host unless [param secrets] is
## set, since nobody's screen should be able to show them.
func to_dict(secrets: bool = false) -> Dictionary:
	var bidder_data: Array = []
	for bidder in bidders:
		var entry := {"id": String(bidder.id), "folded": bidder.folded}
		if secrets:
			entry["estimate"] = bidder.estimate
			entry["max_bid"] = bidder.max_bid
			entry["timer"] = bidder.timer
		bidder_data.append(entry)
	var fire: Dictionary = {}
	for member: StringName in friendly_fire:
		fire[String(member)] = friendly_fire[member]
	return {
		"state": state,
		"opening_price": opening_price,
		"price": price,
		"high_bidder": String(high_bidder),
		"countdown": countdown,
		"crew": _strings(crew),
		"crew_cash": crew_cash,
		"crew_out": _strings(crew_out),
		"friendly_fire": fire,
		"bid_count": bid_count,
		"calls_made": _calls_made,
		"bidders": bidder_data,
	}


## Rebuilds an auction from [method to_dict]. Without the secrets the copy
## can be shown but not run. Building it draws from [param rng], so give a
## copy its own generator, never a game stream.
static func from_dict(data: Dictionary, rules: AuctionRules, catalog: Catalog, rng: RandomNumberGenerator) -> Auction:
	var copy_bidders: Array[RivalBidder] = []
	var bidder_data: Array = data.get("bidders", [])
	for entry: Dictionary in bidder_data:
		var bidder := RivalBidder.new(catalog.rivals[JsonValue.as_name(entry["id"])], JsonValue.as_int(entry.get("max_bid", 0)))
		bidder.estimate = JsonValue.as_int(entry.get("estimate", 0))
		var folded: bool = entry.get("folded", false)
		bidder.folded = folded
		copy_bidders.append(bidder)
	var copy := Auction.new(rules, JsonValue.as_int(data["opening_price"]), copy_bidders, JsonValue.as_names(data.get("crew", [])), JsonValue.as_int(data.get("crew_cash", 0)), rng)
	copy.state = JsonValue.as_int(data.get("state", State.OPEN)) as State
	copy.price = JsonValue.as_int(data.get("price", 0))
	copy.high_bidder = JsonValue.as_name(data.get("high_bidder", ""))
	copy.countdown = JsonValue.as_float(data.get("countdown", rules.countdown_seconds))
	copy.crew_out = JsonValue.as_names(data.get("crew_out", []))
	var fire: Dictionary = data.get("friendly_fire", {})
	for member: Variant in fire:
		copy.friendly_fire[JsonValue.as_name(member)] = JsonValue.as_int(fire[member])
	copy.bid_count = JsonValue.as_int(data.get("bid_count", 0))
	copy._calls_made = JsonValue.as_int(data.get("calls_made", 0))
	# The constructor scheduled the rivals; put the copied timers back.
	for i in copy_bidders.size():
		var entry: Dictionary = bidder_data[i]
		copy_bidders[i].timer = JsonValue.as_float(entry.get("timer", -1.0))
	return copy


static func _strings(names: Array[StringName]) -> Array:
	var out: Array = []
	for each in names:
		out.append(String(each))
	return out


func _place_bid(who: StringName, amount: int, is_jump: bool, events: Array[Dictionary]) -> void:
	var over_crewmate := is_crew(who) and is_crew(high_bidder)
	if over_crewmate:
		friendly_fire[who] = (friendly_fire[who] if friendly_fire.has(who) else 0) + 1
	price = amount
	high_bidder = who
	bid_count += 1
	countdown = _rules.countdown_seconds
	_calls_made = 0
	events.append({"type": "bid", "bidder": who, "amount": amount, "jump": is_jump, "friendly_fire": over_crewmate})
	if is_jump:
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
