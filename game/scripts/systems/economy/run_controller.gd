class_name RunController
extends RefCounted
## Runs the game day by day on top of the pure systems: the morning's
## auctions, hauling, the afternoon in the shop, and the end of the day. It
## owns the RunState and today's DayPlan. Its signals say what changed; the
## GameState autoload forwards them to EventBus for the UI.
##
## A day goes: start_day() → for each locker, open_auction() and
## settle_auction(), then plan_haul() and finish_haul() for a win (or
## skip_locker()) → start_afternoon() → shelve() and set_price() →
## next_customer() and complete_sale() until it returns null → end_day().
##
## The business belongs to a crew of one to four (see Crew) sharing one
## bank. Wins and sales are credited to the member who made them.

signal cash_changed(cash: int)
signal day_started(day: int)
signal locker_settled(lot_number: int, winner: StringName, price: int)
signal item_sold(uid: int, price: int)
signal day_ended(summary: Dictionary)

var catalog: Catalog
var run: RunState
var today: DayPlan = null
var pricing: Pricing
## Who's playing today, in seat order. Not saved: friends come and go
## between sessions, while the business carries on.
var crew: Array[StringName] = Crew.of_size(1)
## The run and the random streams as they stood when the current day began.
## Saves write this, so loading always resumes at the start of a day.
var day_start_snapshot: Dictionary = {}
## The summary end_day() returned last, for the end-of-day screen.
var last_summary: Dictionary = {}

var _rng: RngStreams
var _roller: LootRoller


func _init(p_catalog: Catalog, p_run: RunState, rng: RngStreams) -> void:
	catalog = p_catalog
	run = p_run
	pricing = Pricing.new(p_catalog)
	_rng = rng
	_roller = LootRoller.new(p_catalog)
	_take_snapshot()


## A brand-new run on day 1.
static func new_run(p_catalog: Catalog, rng: RngStreams) -> RunController:
	return RunController.new(p_catalog, RunState.fresh(p_catalog.economy), rng)


## Picks a saved run back up at the start of its day, restoring the random
## streams into [param rng] so the day plays out as it would have.
static func from_snapshot(p_catalog: Catalog, rng: RngStreams, snapshot: Dictionary) -> RunController:
	var rng_state: Dictionary = snapshot.get("rng", {})
	rng.from_dict(rng_state)
	var run_data: Dictionary = snapshot.get("run", {})
	return RunController.new(p_catalog, RunState.from_dict(run_data, p_catalog.economy), rng)


func zone() -> ZoneDef:
	return catalog.zones[run.zone_id]


func vehicle() -> VehicleDef:
	return catalog.vehicles[run.vehicle_id]


## Cash plus everything owned at market value.
func net_worth() -> int:
	var total := run.cash
	for item: ItemInstance in run.items.values():
		total += pricing.market_value(item)
	return total


## Days until rent comes out, at the end of the day. 0 means tonight.
func days_until_rent() -> int:
	var every := catalog.economy.rent_every_days
	return (every - run.day % every) % every


## A scrap job replaces the morning's auctions, for a player too broke to bid.
func can_take_scrap_job() -> bool:
	return today != null and today.phase == DayPlan.Phase.MORNING and today.results.is_empty() and run.cash < catalog.economy.scrap_job_below


# --- Morning ---------------------------------------------------------------

## Rolls today's lockers and rivals. Calling it again mid-day changes nothing.
func start_day() -> DayPlan:
	if today != null and today.phase != DayPlan.Phase.DONE:
		return today
	today = DayPlan.new(run.day, run.cash)
	var here := zone()
	for lot in range(1, here.lockers_per_day + 1):
		today.lockers.append(_roller.roll_locker(here, lot, _rng.stream(&"loot"), run.uids))
	today.roster = RivalRoster.for_day(here, catalog, _rng.stream(&"auction"))
	day_started.emit(run.day)
	return today


## The auction for [param locker], with today's rivals sizing it up.
func open_auction(locker: Locker) -> Auction:
	var bidders := today.roster.bidders_for(locker, pricing, _rng.stream(&"auction"))
	return Auction.new(catalog.economy.auction, locker.opening_price, bidders, crew, maxi(run.cash, 0), _rng.stream(&"auction"))


## Records how a finished auction went: the crew's bank pays for a win, which
## is credited to the member holding the last bid; a rival's win comes out of
## their budget for the rest of the day.
func settle_auction(locker: Locker, auction: Auction) -> void:
	if not _need_phase(DayPlan.Phase.MORNING):
		return
	if auction.is_open() or today.is_settled(locker):
		push_error("Settled lot %d twice, or before the hammer fell." % locker.lot_number)
		return
	var winner := auction.winner()
	today.results[locker.lot_number] = winner
	for member_id: StringName in auction.friendly_fire:
		today.ledger.member(member_id).friendly_fire += auction.friendly_fire[member_id]
	if auction.crew_won():
		today.ledger.spent_on_lockers += auction.price
		today.ledger.lockers_won += 1
		var credit := today.ledger.member(winner)
		credit.lockers_won += 1
		credit.spent_on_lockers += auction.price
		run.lockers_won += 1
		for item in locker.items:
			_note_find(item, winner)
		_change_cash(-auction.price)
	else:
		today.ledger.lockers_lost += 1
		if winner != Auction.NOBODY:
			today.roster.spend(winner, auction.price)
	locker_settled.emit(locker.lot_number, winner, auction.price if winner != Auction.NOBODY else 0)


## The crew sits a locker out; the rivals settle it between themselves.
func skip_locker(locker: Locker) -> void:
	var auction := open_auction(locker)
	for member_id in crew:
		auction.pass_out(member_id)
	auction.run_to_end()
	settle_auction(locker, auction)


## A haul plan for a won locker, loaded with the best value that fits.
func plan_haul(locker: Locker) -> HaulPlan:
	var plan := HaulPlan.new(vehicle(), locker.items, pricing)
	plan.select_best()
	return plan


## Takes the loaded items home to the back room and scraps the rest, junk
## included. Returns the scrap money.
func finish_haul(locker: Locker, plan: HaulPlan) -> int:
	for item in plan.selected_items():
		run.items[item.uid] = item
	var scrap := plan.scrap_value(locker.junk_weight)
	today.ledger.scrap += scrap
	_change_cash(scrap)
	return scrap


## Works a scrap job instead of bidding; the rivals take today's lockers.
func take_scrap_job() -> int:
	if not can_take_scrap_job():
		push_error("No scrap job: it's only offered before any bidding, when cash is low.")
		return 0
	var pay := catalog.economy.scrap_job_pay
	today.ledger.scrap_job += pay
	_change_cash(pay)
	start_afternoon()
	return pay


# --- Afternoon -------------------------------------------------------------

## Opens the shop. Any lockers not yet auctioned go to the rivals.
func start_afternoon() -> void:
	if today == null or today.phase != DayPlan.Phase.MORNING:
		return
	var locker := today.next_locker()
	while locker != null:
		skip_locker(locker)
		locker = today.next_locker()
	today.phase = DayPlan.Phase.AFTERNOON
	today.customers_left = catalog.economy.shop.customers_per_day


## Puts an owned item on a shelf at the suggested price. False if it won't fit.
func shelve(uid: int, shelf: int) -> bool:
	if not run.items.has(uid) or run.shop.is_shelved(uid):
		return false
	var item := run.items[uid]
	return run.shop.place(uid, pricing.def_of(item).size, shelf, pricing.suggested_price(item))


## Moves a shelved item back to the back room.
func unshelve(uid: int) -> void:
	run.shop.remove(uid)


func set_price(uid: int, price: int) -> void:
	run.shop.set_price(uid, price)


## The next shopper, or null once the day's customers are done or there's
## nothing on the shelves. They never pick up an item in [param held], the
## ones other customers already have in hand.
func next_customer(held: Array[int] = []) -> Customer:
	if today == null or today.phase != DayPlan.Phase.AFTERNOON or today.customers_left <= 0:
		return null
	var stock: Array[int] = []
	for uid in run.shop.shelved_uids():
		if not held.has(uid):
			stock.append(uid)
	if stock.is_empty():
		return null
	today.customers_left -= 1
	var rng := _rng.stream(&"customers")
	var shop_rules := catalog.economy.shop
	var kind: StringName = Weighted.pick(shop_rules.customer_weights, rng)
	var uid := stock[rng.randi_range(0, stock.size() - 1)]
	return Customer.approach(catalog.customers[kind], uid, run.shop.price_of[uid], pricing.market_value(run.items[uid]), shop_rules.price_step, rng)


## Hands over an item the customer agreed to buy and takes their money,
## crediting the sale to [param seller].
func complete_sale(customer: Customer, seller: StringName = Crew.HOST) -> void:
	if customer.state != Customer.State.SOLD or not run.items.has(customer.item_uid):
		push_error("No sale to complete for item %d." % customer.item_uid)
		return
	var price := customer.offer
	run.items.erase(customer.item_uid)
	run.shop.remove(customer.item_uid)
	today.ledger.sales += price
	today.ledger.items_sold += 1
	var credit := today.ledger.member(seller)
	credit.sales += price
	credit.items_sold += 1
	_change_cash(price)
	item_sold.emit(customer.item_uid, price)


# --- Evening ---------------------------------------------------------------

## Closes the day: rent if it's due, the summary, then on to tomorrow (which
## is where the next save picks up).
func end_day() -> Dictionary:
	if today == null:
		push_error("No day in progress.")
		return {}
	start_afternoon()
	today.phase = DayPlan.Phase.DONE
	if days_until_rent() == 0:
		today.ledger.rent = catalog.economy.rent_amount
		_change_cash(-catalog.economy.rent_amount)
	var summary := today.ledger.to_dict()
	var crew_names: Array = []
	for member in crew:
		crew_names.append(String(member))
	summary["crew"] = crew_names
	summary["end_cash"] = run.cash
	summary["net_worth"] = net_worth()
	run.day += 1
	summary["rent_due_in"] = days_until_rent()
	last_summary = summary
	_take_snapshot()
	day_ended.emit(summary)
	return summary


func _need_phase(phase: DayPlan.Phase) -> bool:
	if today == null or today.phase != phase:
		push_error("That can't happen at this point in the day.")
		return false
	return true


func _note_find(item: ItemInstance, finder: StringName) -> void:
	var value := pricing.market_value(item)
	today.ledger.note_find(item.def_id, value, finder)
	if value > run.best_find_value:
		run.best_find_def = item.def_id
		run.best_find_value = value


func _change_cash(delta: int) -> void:
	run.cash += delta
	cash_changed.emit(run.cash)


func _take_snapshot() -> void:
	day_start_snapshot = {"run": run.to_dict(), "rng": _rng.to_dict()}
