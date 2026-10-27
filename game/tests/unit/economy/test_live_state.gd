extends GutTest
## A day in progress copies to plain data and back without losing anything a
## screen shows, so other players can be sent it. Secrets (rival max bids,
## customer limits) only travel when asked for.

const Fixture := preload("res://tests/helpers/fixture.gd")

var catalog: Catalog
var controller: RunController


func before_each() -> void:
	catalog = Fixture.catalog()
	controller = RunController.new_run(catalog, RngStreams.new(3))
	controller.start_day()


func test_a_locker_round_trips() -> void:
	var locker := controller.today.lockers[0]
	var copy := Locker.from_dict(_through_json(locker.to_dict()))
	assert_eq(copy.to_dict(), locker.to_dict())
	assert_eq(copy.visible_items_for(1).size(), locker.visible_items_for(1).size())


func test_the_day_round_trips() -> void:
	controller.skip_locker(controller.today.lockers[0])
	var copy := DayPlan.from_dict(_through_json(controller.today.to_dict()), catalog)
	assert_eq(copy.to_dict(), controller.today.to_dict())
	assert_eq(copy.next_locker().lot_number, 2)
	assert_eq(copy.roster.budget_of(&"shark"), controller.today.roster.budget_of(&"shark"))


func test_the_ledger_round_trips_with_each_members_part() -> void:
	var ledger := controller.today.ledger
	ledger.member(&"p2").friendly_fire = 3
	ledger.sales = 120
	var copy := DayLedger.from_dict(_through_json(ledger.to_dict()))
	assert_eq(copy.to_dict(), ledger.to_dict())
	assert_eq(copy.member(&"p2").friendly_fire, 3)


func test_an_auction_copy_shows_the_same_auction_without_secrets() -> void:
	var auction := controller.open_auction(controller.today.lockers[0])
	auction.raise(Crew.HOST)
	auction.advance(1.2)
	var shown := auction.to_dict()
	for entry: Dictionary in shown["bidders"]:
		assert_false(entry.has("max_bid"), "rival max bids stay on the host")
	var copy := Auction.from_dict(_through_json(shown), catalog.economy.auction, catalog, RandomNumberGenerator.new())
	assert_eq(copy.to_dict(), shown)
	assert_eq(copy.next_bid(), auction.next_bid())
	assert_eq(copy.winner(), auction.winner())


func test_an_auction_copied_with_secrets_plays_on_the_same() -> void:
	var auction := controller.open_auction(controller.today.lockers[0])
	auction.raise(Crew.HOST)
	auction.advance(0.7)
	var copy := Auction.from_dict(_through_json(auction.to_dict(true)), catalog.economy.auction, catalog, RandomNumberGenerator.new())
	assert_eq(copy.advance(30.0), auction.advance(30.0), "no jump bids, so no dice: same events")
	assert_eq(copy.winner(), auction.winner())
	assert_eq(copy.price, auction.price)


func test_a_customer_copy_hides_their_limit() -> void:
	var item := Fixture.item(1, &"chair", 100)
	controller.run.items[1] = item
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var customer := Customer.approach(catalog.customers[&"haggler"], 1, 100, 100, 5, rng)
	var shown := customer.to_dict()
	assert_false(shown.has("limit"))
	var copy := Customer.from_dict(_through_json(shown), catalog, 5)
	assert_eq(copy.to_dict(), shown)
	assert_eq(Customer.from_dict(_through_json(customer.to_dict(true)), catalog, 5).limit, customer.limit)


func test_a_haul_plan_copies_its_load() -> void:
	var locker := controller.today.lockers[0]
	var plan := controller.plan_haul(locker)
	var copy := HaulPlan.new(controller.vehicle(), locker.items, controller.pricing)
	copy.set_selected(plan.selected_uids())
	assert_eq(copy.selected_uids(), plan.selected_uids())
	assert_eq(copy.weight_used(), plan.weight_used())


## Sends [param data] through JSON text and back, as a save or the network
## would, so number types change the way they would there.
func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	return parsed
