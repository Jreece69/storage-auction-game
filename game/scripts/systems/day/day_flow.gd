class_name DayFlow
extends RefCounted
## The day as the crew plays it together: the start of the day, then the
## morning's lockers one at a time (peek, bidding, result, reveal, haul),
## then the afternoon in the shop and the end-of-day summary. It runs the
## clocks and takes the crew's moves; the rules stay in RunController.
##
## The host runs the one real DayFlow. Every move goes through
## [method handle] with the crew member who made it, so a move from a player
## on another machine is the same call as one from this machine. Other
## players see copies (see [method mirror]) kept up to date with the host's
## [method run_dict], [method today_dict] and [method flow_dict].
##
## Moves anyone can make go through at once. Moves that would cut a crewmate
## short (starting the bidding early, driving home, closing up) wait until
## the whole crew agrees.

## Something a screen shows changed. Clocks run down without it.
signal changed
## What happened in the auction (see Auction), in order, for feeds and
## effects.
signal auction_events(events: Array[Dictionary])
## The shop closed and the day ended: the host saves now.
signal day_closed

enum Stage { MAP, PEEK, BIDDING, RESULT, REVEAL, HAUL, MORNING_DONE, SHOP, SUMMARY }

## Once the whole crew is out, the rivals settle an auction this much faster.
const FAST_FORWARD: float = 4.0
## Seconds between items coming out during the reveal.
const REVEAL_INTERVAL: float = 0.45

var controller: RunController
var stage: Stage = Stage.MAP
## The locker on the block, from the peek to the haul. Null between lockers.
var locker: Locker = null
## Seconds left to look before the bidding opens.
var peek_left: float = 0.0
var auction: Auction = null
## Who won the last locker: a crew member, a rival id, or Auction.NOBODY.
var winner: StringName = Auction.NOBODY
var price: int = 0
## How many of the locker's items have come out in the reveal.
var revealed: int = 0
var haul: HaulPlan = null
## Who has agreed to the step waiting on the whole crew.
var ready: Array[StringName] = []
## Who is sitting the locker on the block out.
var sitting_out: Array[StringName] = []
## Each crew member's place at the shop counter.
var counters: Dictionary[StringName, ShopCounter] = {}

var _reveal_wait: float = 0.0
## A copy's lot number on the block, kept to find the locker again when a
## newer copy of today arrives.
var _lot: int = 0


func _init(p_controller: RunController) -> void:
	controller = p_controller


## Starts the day the controller is on, at the start-of-day screen. Only the
## host calls this; copies get their state from the host.
func start() -> void:
	_enter_map()
	changed.emit()


func crew() -> Array[StringName]:
	return controller.crew


## Whether every crew member has agreed to the step that's waiting.
func all_ready() -> bool:
	for member in controller.crew:
		if not ready.has(member):
			return false
	return true


## Whether the crew won the last locker.
func crew_won() -> bool:
	return controller.crew.has(winner)


## The items customers have in hand right now, which nobody else can buy.
func held_items() -> Array[int]:
	var held: Array[int] = []
	for member: StringName in counters:
		var counter := counters[member]
		if counter.is_busy():
			held.append(counter.customer.item_uid)
	return held


## The counter of [param member], made on first use.
func counter_of(member: StringName) -> ShopCounter:
	if not counters.has(member):
		counters[member] = ShopCounter.new()
	return counters[member]


## Whether another customer could still come in today.
func more_customers() -> bool:
	var today := controller.today
	if today == null or today.customers_left <= 0:
		return false
	for uid in controller.run.shop.shelved_uids():
		if not held_items().has(uid):
			return true
	return false


# --- Moves -------------------------------------------------------------------

## Makes the move [param command] for crew member [param member]. Returns
## false, changing nothing, when the move doesn't fit the moment: the wrong
## stage, a bid they can't make, a customer who isn't there.
func handle(member: StringName, command: String, args: Dictionary = {}) -> bool:
	if not controller.crew.has(member):
		return false
	var done := false
	match command:
		"go_to_auction":
			done = _go_to_auction()
		"skip_to_shop":
			done = _skip_to_shop()
		"scrap_job":
			done = _scrap_job()
		"ready":
			done = _ready_to_bid(member, false)
		"sit_out":
			done = _ready_to_bid(member, true)
		"raise":
			done = _bid(member, false)
		"jump":
			done = _bid(member, true)
		"pass":
			done = _pass(member)
		"continue":
			done = _continue()
		"show_all":
			done = _show_all()
		"load":
			done = _load()
		"toggle":
			done = _toggle(JsonValue.as_int(args.get("uid", -1)))
		"drive":
			done = _drive(member)
		"open_shop":
			done = _open_shop()
		"shelve":
			done = _shelve(JsonValue.as_int(args.get("uid", -1)))
		"unshelve":
			done = _unshelve(JsonValue.as_int(args.get("uid", -1)))
		"reprice":
			done = _reprice(JsonValue.as_int(args.get("uid", -1)), JsonValue.as_int(args.get("steps", 0)))
		"next_customer":
			done = _next_customer(member)
		"accept":
			done = _accept(member)
		"counter":
			done = _counter(member, JsonValue.as_int(args.get("amount", 0)))
		"decline":
			done = _decline(member)
		"close_up":
			done = _close_up(member)
		"next_day":
			done = _next_day()
	if done:
		changed.emit()
	return done


## Runs [param seconds] of the host's clocks: the peek, the auction, the
## reveal.
func tick(seconds: float) -> void:
	match stage:
		Stage.PEEK:
			peek_left = maxf(peek_left - seconds, 0.0)
			if peek_left <= 0.0:
				_open_bidding()
				changed.emit()
		Stage.BIDDING:
			var speed := FAST_FORWARD if auction.all_crew_out() else 1.0
			if _after_auction(auction.advance(seconds * speed)):
				changed.emit()
		Stage.REVEAL:
			_reveal_wait -= seconds
			var before := revealed
			while _reveal_wait <= 0.0 and revealed < locker.items.size():
				revealed += 1
				_reveal_wait += REVEAL_INTERVAL
			if revealed != before:
				changed.emit()


## A crew member's machine dropped out. They pass on the locker on the
## block and their customer is let go; the crew carries on without them.
func drop_member(member: StringName) -> void:
	if not controller.crew.has(member):
		return
	if auction != null and auction.is_open():
		auction.pass_out(member)
	controller.crew.erase(member)
	ready.erase(member)
	sitting_out.erase(member)
	if counters.has(member):
		var counter := counters[member]
		if counter.is_busy():
			counter.customer.decline()
		counters.erase(member)
	_check_votes()
	changed.emit()


# --- Start of the day ---------------------------------------------------------

func _enter_map() -> void:
	controller.start_day()
	stage = Stage.MAP
	_clear_locker()
	counters.clear()
	ready.clear()


func _go_to_auction() -> bool:
	if stage != Stage.MAP or controller.today.phase != DayPlan.Phase.MORNING:
		return false
	_next_locker()
	return true


func _skip_to_shop() -> bool:
	if stage != Stage.MAP:
		return false
	controller.start_afternoon()
	_enter_shop()
	return true


func _scrap_job() -> bool:
	if stage != Stage.MAP or not controller.can_take_scrap_job():
		return false
	controller.take_scrap_job()
	_enter_shop()
	return true


# --- The morning ---------------------------------------------------------------

func _clear_locker() -> void:
	locker = null
	auction = null
	haul = null
	winner = Auction.NOBODY
	price = 0
	revealed = 0
	peek_left = 0.0
	sitting_out.clear()


func _next_locker() -> void:
	_clear_locker()
	ready.clear()
	locker = controller.today.next_locker()
	if locker == null:
		stage = Stage.MORNING_DONE
		return
	stage = Stage.PEEK
	peek_left = controller.catalog.economy.auction.peek_seconds


## Ready to bid, or sitting it out. The bidding opens once everyone has said.
func _ready_to_bid(member: StringName, sit_out: bool) -> bool:
	if stage != Stage.PEEK or ready.has(member):
		return false
	ready.append(member)
	if sit_out:
		sitting_out.append(member)
	_check_votes()
	return true


func _open_bidding() -> void:
	auction = controller.open_auction(locker)
	for member in sitting_out:
		auction.pass_out(member)
	stage = Stage.BIDDING
	ready.clear()
	# Nobody's bidding: the rivals settle it at once.
	if auction.all_crew_out():
		_after_auction(auction.run_to_end())


func _bid(member: StringName, is_jump: bool) -> bool:
	if stage != Stage.BIDDING:
		return false
	var events := auction.jump(member) if is_jump else auction.raise(member)
	if events.is_empty():
		return false
	_after_auction(events)
	return true


func _pass(member: StringName) -> bool:
	if stage != Stage.BIDDING or auction.crew_out.has(member):
		return false
	auction.pass_out(member)
	return true


## Passes the auction's news on, and settles the locker once the hammer
## falls. Returns whether anything happened.
func _after_auction(events: Array[Dictionary]) -> bool:
	if events.is_empty():
		return false
	auction_events.emit(events)
	if not auction.is_open():
		controller.settle_auction(locker, auction)
		winner = auction.winner()
		price = auction.price if winner != Auction.NOBODY else 0
		stage = Stage.RESULT
	return true


func _continue() -> bool:
	if stage != Stage.RESULT:
		return false
	if crew_won():
		stage = Stage.REVEAL
		revealed = 0
		_reveal_wait = REVEAL_INTERVAL
	else:
		_next_locker()
	return true


func _show_all() -> bool:
	if stage != Stage.REVEAL or revealed >= locker.items.size():
		return false
	revealed = locker.items.size()
	return true


func _load() -> bool:
	if stage != Stage.REVEAL or revealed < locker.items.size():
		return false
	haul = controller.plan_haul(locker)
	stage = Stage.HAUL
	ready.clear()
	return true


func _toggle(uid: int) -> bool:
	return stage == Stage.HAUL and haul.toggle(uid)


func _drive(member: StringName) -> bool:
	if stage != Stage.HAUL or ready.has(member):
		return false
	ready.append(member)
	_check_votes()
	return true


func _open_shop() -> bool:
	if stage != Stage.MORNING_DONE:
		return false
	controller.start_afternoon()
	_enter_shop()
	return true


# --- The afternoon ---------------------------------------------------------------

func _enter_shop() -> void:
	_clear_locker()
	stage = Stage.SHOP
	ready.clear()
	counters.clear()
	var extra := controller.catalog.economy.shop.crew_extra_customers * (controller.crew.size() - 1)
	controller.today.customers_left += maxi(extra, 0)
	for member in controller.crew:
		counter_of(member)


func _shelve(uid: int) -> bool:
	if stage != Stage.SHOP:
		return false
	for shelf in controller.run.shop.shelf_count:
		if controller.shelve(uid, shelf):
			return true
	return false


func _unshelve(uid: int) -> bool:
	if stage != Stage.SHOP or not controller.run.shop.is_shelved(uid) or held_items().has(uid):
		return false
	controller.unshelve(uid)
	return true


func _reprice(uid: int, steps: int) -> bool:
	var shop := controller.run.shop
	if stage != Stage.SHOP or not shop.is_shelved(uid) or steps == 0:
		return false
	var step := controller.catalog.economy.shop.price_step
	var new_price := maxi(step, shop.price_of[uid] + steps * step)
	if new_price == shop.price_of[uid]:
		return false
	controller.set_price(uid, new_price)
	return true


func _next_customer(member: StringName) -> bool:
	var counter := counter_of(member)
	if stage != Stage.SHOP or counter.is_busy():
		return false
	var customer := controller.next_customer(held_items())
	if customer == null:
		return false
	counter.customer = customer
	counter.item_def = controller.run.items[customer.item_uid].def_id
	counter.amount = 0
	if customer.is_offering():
		counter.outcome = ShopCounter.Outcome.NONE
	elif customer.reason == Customer.Reason.BROWSING:
		counter.outcome = ShopCounter.Outcome.BROWSING
	else:
		counter.outcome = ShopCounter.Outcome.TOO_PRICEY
	return true


func _accept(member: StringName) -> bool:
	var counter := counter_of(member)
	if stage != Stage.SHOP or not counter.is_busy():
		return false
	var sale := counter.customer.accept()
	controller.complete_sale(counter.customer, member)
	counter.outcome = ShopCounter.Outcome.SOLD
	counter.amount = sale
	return true


func _counter(member: StringName, amount: int) -> bool:
	var counter := counter_of(member)
	if stage != Stage.SHOP or not counter.is_busy() or amount <= counter.customer.offer:
		return false
	match counter.customer.counter(amount):
		"accept":
			controller.complete_sale(counter.customer, member)
			counter.outcome = ShopCounter.Outcome.DEAL
			counter.amount = counter.customer.offer
		"raise":
			counter.outcome = ShopCounter.Outcome.RAISED
			counter.amount = counter.customer.offer
		_:
			counter.outcome = ShopCounter.Outcome.LOST_PATIENCE
			counter.amount = 0
	return true


func _decline(member: StringName) -> bool:
	var counter := counter_of(member)
	if stage != Stage.SHOP or not counter.is_busy():
		return false
	counter.customer.decline()
	counter.outcome = ShopCounter.Outcome.DECLINED
	counter.amount = 0
	return true


func _close_up(member: StringName) -> bool:
	if stage != Stage.SHOP or ready.has(member):
		return false
	ready.append(member)
	_check_votes()
	return true


# --- The evening ---------------------------------------------------------------

func _next_day() -> bool:
	if stage != Stage.SUMMARY:
		return false
	_enter_map()
	return true


## Moves on once the whole crew agrees, for the steps that wait on everyone.
func _check_votes() -> void:
	if controller.crew.is_empty() or not all_ready():
		return
	match stage:
		Stage.PEEK:
			_open_bidding()
		Stage.HAUL:
			controller.finish_haul(locker, haul)
			_next_locker()
		Stage.SHOP:
			for member: StringName in counters:
				if counters[member].is_busy():
					counters[member].customer.decline()
			controller.end_day()
			stage = Stage.SUMMARY
			ready.clear()
			counters.clear()
			day_closed.emit()


# --- Copies for other players ------------------------------------------------------

## Everything a screen shows about the run (cash, stock, shelves).
func run_dict() -> Dictionary:
	return controller.run.to_dict()


## Everything about today so far (lockers, results, the ledger).
func today_dict() -> Dictionary:
	return controller.today.to_dict() if controller.today != null else {}


## Where the day is: the stage, the clocks, the auction, the haul, the votes,
## the counters. Small, so it can be sent often.
func flow_dict() -> Dictionary:
	var counter_data: Dictionary = {}
	for member: StringName in counters:
		counter_data[String(member)] = counters[member].to_dict()
	var haul_data: Variant = null
	if haul != null:
		haul_data = haul.selected_uids()
	return {
		"stage": stage,
		"crew": _strings(controller.crew),
		"lot": locker.lot_number if locker != null else 0,
		"peek_left": peek_left,
		"auction": auction.to_dict() if auction != null else {},
		"winner": String(winner),
		"price": price,
		"revealed": revealed,
		"haul": haul_data,
		"ready": _strings(ready),
		"sitting_out": _strings(sitting_out),
		"counters": counter_data,
		"last_summary": controller.last_summary,
	}


## A copy of the host's day for another player's screens. It shows the day
## but never runs it: moves go to the host instead.
static func mirror(catalog: Catalog, run_data: Dictionary, today_data: Dictionary, flow_data: Dictionary) -> DayFlow:
	var copy_controller := RunController.new(catalog, RunState.from_dict(run_data, catalog.economy), RngStreams.new(0))
	var copy := DayFlow.new(copy_controller)
	copy.apply_today(today_data)
	copy.apply_flow(flow_data)
	return copy


func apply_run(data: Dictionary) -> void:
	controller.run = RunState.from_dict(data, controller.catalog.economy)
	changed.emit()


func apply_today(data: Dictionary) -> void:
	controller.today = DayPlan.from_dict(data, controller.catalog) if not data.is_empty() else null
	_relink_locker()
	changed.emit()


func apply_flow(data: Dictionary) -> void:
	var catalog := controller.catalog
	stage = JsonValue.as_int(data.get("stage", Stage.MAP)) as Stage
	controller.crew = JsonValue.as_names(data.get("crew", [Crew.HOST]))
	_lot = JsonValue.as_int(data.get("lot", 0))
	_relink_locker()
	peek_left = JsonValue.as_float(data.get("peek_left", 0.0))
	var auction_data: Dictionary = data.get("auction", {})
	auction = Auction.from_dict(auction_data, catalog.economy.auction, catalog, RandomNumberGenerator.new()) if not auction_data.is_empty() else null
	winner = JsonValue.as_name(data.get("winner", ""))
	price = JsonValue.as_int(data.get("price", 0))
	revealed = JsonValue.as_int(data.get("revealed", 0))
	var haul_data: Variant = data.get("haul")
	if haul_data == null or locker == null:
		haul = null
	else:
		haul = HaulPlan.new(controller.vehicle(), locker.items, controller.pricing)
		var loaded: Array[int] = []
		var uids: Array = haul_data
		for uid: Variant in uids:
			loaded.append(JsonValue.as_int(uid))
		haul.set_selected(loaded)
	ready = JsonValue.as_names(data.get("ready", []))
	sitting_out = JsonValue.as_names(data.get("sitting_out", []))
	counters.clear()
	var counter_data: Dictionary = data.get("counters", {})
	for member: Variant in counter_data:
		var entry: Dictionary = counter_data[member]
		counters[JsonValue.as_name(member)] = ShopCounter.from_dict(entry, catalog, catalog.economy.shop.price_step)
	var summary: Dictionary = data.get("last_summary", {})
	controller.last_summary = summary
	changed.emit()


## Runs a copy's clocks down between the host's updates, so they move
## smoothly. Changes nothing else.
func tick_clocks(seconds: float) -> void:
	if stage == Stage.PEEK:
		peek_left = maxf(peek_left - seconds, 0.0)
	elif stage == Stage.BIDDING and auction != null and auction.is_open():
		auction.countdown = maxf(auction.countdown - seconds, 0.0)


## Points [member locker] at today's locker with the copied lot number.
func _relink_locker() -> void:
	locker = null
	if controller.today == null or _lot <= 0:
		return
	for each in controller.today.lockers:
		if each.lot_number == _lot:
			locker = each


static func _strings(names: Array[StringName]) -> Array:
	var out: Array = []
	for each in names:
		out.append(String(each))
	return out
