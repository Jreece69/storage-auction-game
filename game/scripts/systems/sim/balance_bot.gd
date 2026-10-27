class_name BalanceBot
extends RefCounted
## A plain, sensible player for the balance sim. It sizes up each locker from
## what it can see through the door, bids up to a share of that, hauls the
## best load, prices everything at the suggestion and takes any fair offer.
## Deliberately simple: if this bot can make a living, so can a person.
##
## It can also read the sharp rivals the way a player learns to: a shark
## still bidding means the locker is worth well over the price, and the price
## a shark drops out at says roughly what it's worth.
##
## It plays through RunController exactly as the screens do, so the sim
## measures the real rules.

## Bids up to this share of its estimate of the locker.
var bid_share: float = 0.6
## Whether it reads the sharp rivals (see the class description).
var reads_rivals: bool = false
## Whether its first bid on a locker is a jump bid when a rival who scares
## easily (this likely to fold to a jump, or more) is still in.
var jumps_at_skittish: bool = false
var skittish_chance: float = 0.3
## Rivals this accurate (estimate noise at or below it) are worth reading.
var sharp_noise: float = 0.1
## Takes any offer worth at least this share of the price tag.
var accept_share: float = 0.85
## How often it looks at the auction, in game seconds.
var reaction_seconds: float = 0.5
## Keeps the rent back when it's due within this many days.
var rent_caution_days: int = 2
## Sits the auctions out while it owns this many unsold items or more, so
## its money isn't all tied up in stock. 0 means no limit.
var max_stock: int = 0

var controller: RunController
var member: StringName = Crew.HOST
## One entry per locker won: the day, price paid, contents value, best
## item's value, and the market value of what didn't fit in the van.
var wins: Array[Dictionary] = []
var scrap_jobs: int = 0


func _init(p_controller: RunController) -> void:
	controller = p_controller


## Plays one whole day and returns its end-of-day summary.
func play_day() -> Dictionary:
	controller.start_day()
	if controller.can_take_scrap_job():
		controller.take_scrap_job()
		scrap_jobs += 1
	elif max_stock > 0 and controller.run.items.size() >= max_stock:
		controller.start_afternoon()
	else:
		var locker := controller.today.next_locker()
		while locker != null:
			_bid_on(locker)
			locker = controller.today.next_locker()
		controller.start_afternoon()
	_stock_shelves()
	_serve_customers()
	return controller.end_day()


## What the bot thinks [param locker] is worth: the typical value of what
## it can see, scaled up to the whole locker, plus the junk as scrap. Like a
## player who knows the price guide but not each item's condition.
func estimate(locker: Locker) -> int:
	var seen := locker.visible_items_for(Crew.seat_of(member))
	if seen.is_empty():
		return 0
	var typical := 0.0
	for item in seen:
		var def := controller.pricing.def_of(item)
		typical += (def.value_min + def.value_max) / 2.0
	var scaled := typical * locker.items.size() / seen.size()
	return roundi(scaled) + controller.pricing.junk_value(locker.junk_weight)


## The most the bot will spend right now.
func spendable() -> int:
	var cash := controller.run.cash
	if controller.days_until_rent() <= rent_caution_days:
		cash -= controller.catalog.economy.rent_amount
	return maxi(cash, 0)


## What the sharp rivals' bidding says the locker is worth: at least the
## price over the most they'd pay for it while one is still in, and about
## the price over their usual margin once one drops out. 0 when no sharp
## rival has shown anything.
func read(auction: Auction, dropped_at: Dictionary[StringName, int]) -> float:
	var implied := 0.0
	var price := auction.price if auction.high_bidder != Auction.NOBODY else auction.opening_price
	for bidder in auction.bidders:
		var def := bidder.def
		if def.estimate_noise > sharp_noise:
			continue
		if dropped_at.has(bidder.id):
			implied = maxf(implied, dropped_at[bidder.id] / ((def.risk_min + def.risk_max) / 2.0))
		elif not bidder.folded:
			implied = maxf(implied, price / def.risk_max)
	return implied


func _bid_on(locker: Locker) -> void:
	var own_estimate := float(estimate(locker))
	var auction := controller.open_auction(locker)
	# Rival → the bid they wouldn't make when they dropped out.
	var dropped_at: Dictionary[StringName, int] = {}
	var bid_yet := false
	while auction.is_open():
		if auction.high_bidder != member:
			var worth := maxf(own_estimate, read(auction, dropped_at)) if reads_rivals else own_estimate
			var limit := mini(roundi(worth * bid_share), spendable())
			var amount := auction.next_bid()
			if amount > limit or not auction.can_bid(member, amount):
				# Out of its range: let the rivals settle it.
				auction.pass_out(member)
				auction.run_to_end()
				break
			var before_raise := auction.next_bid()
			var jump := jumps_at_skittish and not bid_yet and _skittish_rival_in(auction) and auction.jump_bid() <= limit
			_note_drops(auction.jump(member) if jump else auction.raise(member), before_raise, dropped_at)
			bid_yet = true
		var before_wait := auction.next_bid()
		_note_drops(auction.advance(reaction_seconds), before_wait, dropped_at)
	controller.settle_auction(locker, auction)
	if auction.crew_won():
		var plan := controller.plan_haul(locker)
		_note_win(locker, auction.price, plan)
		controller.finish_haul(locker, plan)


func _skittish_rival_in(auction: Auction) -> bool:
	for bidder in auction.bidders:
		if not bidder.folded and bidder.def.jump_fold_chance >= skittish_chance:
			return true
	return false


## Remembers the bid each rival declined when they dropped out.
## [param next_bid] is what the next bid was before [param events] happened.
func _note_drops(events: Array[Dictionary], next_bid: int, dropped_at: Dictionary[StringName, int]) -> void:
	var declined := next_bid
	var rules := controller.catalog.economy.auction
	for event in events:
		var kind: String = event["type"]
		if kind == "bid":
			var amount := JsonValue.as_int(event["amount"])
			declined = amount + rules.raise_amount(amount)
		elif kind == "fold":
			dropped_at[JsonValue.as_name(event["bidder"])] = declined


func _note_win(locker: Locker, price: int, plan: HaulPlan) -> void:
	var best := 0
	for item in locker.items:
		best = maxi(best, controller.pricing.market_value(item))
	var left_behind := 0
	for item in plan.left_behind():
		left_behind += controller.pricing.market_value(item)
	wins.append({"day": controller.run.day, "price": price, "value": controller.pricing.locker_value(locker), "best_item": best, "left_behind": left_behind})


## Puts everything from the back room on the first shelf with room for it.
func _stock_shelves() -> void:
	for uid in controller.run.backroom_uids():
		for shelf in controller.run.shop.shelf_count:
			if controller.shelve(uid, shelf):
				break


func _serve_customers() -> void:
	var customer := controller.next_customer()
	while customer != null:
		_haggle(customer)
		customer = controller.next_customer()


## Takes a fair offer, otherwise holds out for the tag until the customer's
## last offer, which it takes rather than lose the sale.
func _haggle(customer: Customer) -> void:
	while customer.is_offering():
		if customer.offer >= customer.tag * accept_share or customer.patience_left <= 0:
			customer.accept()
		else:
			customer.counter(customer.tag)
	if customer.state == Customer.State.SOLD:
		controller.complete_sale(customer, member)
