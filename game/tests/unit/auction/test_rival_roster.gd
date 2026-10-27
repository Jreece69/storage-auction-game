extends GutTest
## Rival max bids: estimate × risk appetite, capped by what's left of the
## day's budget, with the collector paying extra for their category.
## Fixture rivals have no estimate noise: the rookie bids up to 1.2× value
## from a $500 budget, the shark 0.7× from $2,000, and the collector 0.8×
## from $1,000, doubling their estimate for an all-toys locker.

const Fixture := preload("res://tests/helpers/fixture.gd")

var catalog: Catalog
var pricing: Pricing
var roster: RivalRoster


func before_each() -> void:
	catalog = Fixture.catalog()
	pricing = Pricing.new(catalog)
	roster = RivalRoster.for_day(catalog.zones[&"yard"], catalog, _rng())


func test_budgets_come_from_the_rival_data() -> void:
	assert_eq(roster.budget_of(&"rook"), 500)
	assert_eq(roster.budget_of(&"shark"), 2000)
	assert_eq(roster.budget_of(&"collector"), 1000)


func test_max_bid_is_estimate_times_appetite() -> void:
	var bids := _max_bids(Fixture.locker([Fixture.item(1, &"chair", 100)] as Array[ItemInstance]))
	assert_eq(bids[&"rook"], 120, "the rookie overpays")
	assert_eq(bids[&"shark"], 70, "the shark wants a profit")
	assert_eq(bids[&"collector"], 80, "no toys, no premium")


func test_max_bid_never_exceeds_the_budget() -> void:
	var items: Array[ItemInstance] = []
	for uid in 5:
		items.append(Fixture.item(uid, &"chair", 100))
	assert_eq(_max_bids(Fixture.locker(items))[&"rook"], 500, "1.2 × $500 would be $600")


func test_collector_overpays_for_their_category() -> void:
	var all_toys := Fixture.locker([Fixture.item(1, &"doll", 50)] as Array[ItemInstance])
	assert_eq(_max_bids(all_toys)[&"collector"], 80, "estimate doubled to $100, bids 0.8 of it")
	var half_toys := Fixture.locker([Fixture.item(1, &"doll", 50), Fixture.item(2, &"chair", 50)] as Array[ItemInstance])
	assert_eq(_max_bids(half_toys)[&"collector"], 120, "half the value in toys: estimate × 1.5")


func test_spending_carries_through_the_day() -> void:
	roster.spend(&"rook", 450)
	assert_eq(roster.budget_of(&"rook"), 50)
	var bids := _max_bids(Fixture.locker([Fixture.item(1, &"chair", 100)] as Array[ItemInstance]))
	assert_eq(bids[&"rook"], 50, "a drained rival can't chase the next locker")
	roster.spend(&"rook", 100)
	assert_eq(roster.budget_of(&"rook"), 0, "never below zero")


func _max_bids(locker: Locker) -> Dictionary[StringName, int]:
	var bids: Dictionary[StringName, int] = {}
	for bidder in roster.bidders_for(locker, pricing, _rng()):
		bids[bidder.id] = bidder.max_bid
	return bids


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	return rng
