extends GutTest
## A whole day through the RunController, on fixture content: lockers and
## rivals in the morning, a win, the haul, the shop, a sale, and the end of
## the day with rent. Fixture: $1,000 starting cash, 3 lockers a day, a
## 100 lb / 4-slot van, 2 shelves of 3 slots, 4 customers a day, $100 rent
## every 7 days, a $50 scrap job offered under $100.

const Fixture := preload("res://tests/helpers/fixture.gd")

var controller: RunController


func before_each() -> void:
	controller = RunController.new_run(Fixture.catalog(), RngStreams.new(11))


func test_new_run_starts_from_the_data() -> void:
	assert_eq(controller.run.day, 1)
	assert_eq(controller.run.cash, 1000)
	assert_eq(controller.net_worth(), 1000)
	assert_eq(controller.days_until_rent(), 6)


func test_start_day_rolls_the_lockers_and_rivals() -> void:
	var day := controller.start_day()
	assert_eq(day.lockers.size(), 3)
	for i in 3:
		assert_eq(day.lockers[i].lot_number, i + 1)
	assert_eq(day.roster.budget_of(&"shark"), 2000)
	assert_same(controller.start_day(), day, "asking again mid-day gives the same day")


func test_winning_a_locker_costs_its_price() -> void:
	var locker := _cheap_locker_as_lot_one()
	var auction := controller.open_auction(locker)
	_win(auction)
	controller.settle_auction(locker, auction)
	assert_eq(auction.winner(), Auction.PLAYER)
	assert_eq(controller.run.cash, 1000 - auction.price)
	assert_eq(controller.today.ledger.spent_on_lockers, auction.price)
	assert_eq(controller.today.ledger.lockers_won, 1)
	assert_eq(controller.today.ledger.best_find_def, &"anvil", "the $200 anvil, even though it won't fit in the van")
	assert_eq(controller.today.results[1], Auction.PLAYER)


func test_hauling_brings_items_home_and_scraps_the_rest() -> void:
	var locker := _cheap_locker_as_lot_one()
	var auction := controller.open_auction(locker)
	_win(auction)
	controller.settle_auction(locker, auction)
	var cash_after_auction := controller.run.cash
	var plan := controller.plan_haul(locker)
	# The anvil is too heavy for the van; it and 100 lb of junk go for scrap.
	assert_eq(plan.left_behind().size(), 1)
	var scrap := controller.finish_haul(locker, plan)
	assert_eq(scrap, 25, "150 lb anvil + 100 lb junk at $0.10")
	assert_eq(controller.run.cash, cash_after_auction + 25)
	assert_eq(controller.run.backroom_uids(), [901, 902] as Array[int])


func test_skipped_lockers_go_to_the_rivals() -> void:
	controller.start_day()
	controller.start_afternoon()
	assert_eq(controller.today.results.size(), 3, "every lot was settled")
	assert_eq(controller.run.cash, 1000)
	for lot: int in controller.today.results:
		var winner := controller.today.results[lot]
		assert_ne(winner, Auction.PLAYER)


func test_a_rival_win_comes_out_of_their_budget() -> void:
	var day := controller.start_day()
	var before: Dictionary[StringName, int] = day.roster.budgets.duplicate()
	controller.skip_locker(day.lockers[0])
	var winner := day.results[1]
	if winner == Auction.NOBODY:
		pass_test("this locker went unsold")
		return
	assert_lt(day.roster.budget_of(winner), before[winner])


func test_selling_in_the_afternoon() -> void:
	_own(Fixture.item(901, &"chair", 100))
	controller.start_day()
	controller.start_afternoon()
	assert_true(controller.shelve(901, 0))
	assert_eq(controller.run.shop.price_of[901], 100, "tagged at the suggested price")
	var customer := controller.next_customer()
	assert_eq(customer.item_uid, 901)
	customer.accept()
	controller.complete_sale(customer)
	assert_eq(controller.run.cash, 1000 + customer.offer)
	assert_false(controller.run.items.has(901))
	assert_false(controller.run.shop.is_shelved(901))
	assert_eq(controller.today.ledger.items_sold, 1)


func test_no_customers_without_stock_or_after_the_last_one() -> void:
	controller.start_day()
	controller.start_afternoon()
	assert_null(controller.next_customer(), "nothing on the shelves")
	_own(Fixture.item(901, &"chair", 100))
	controller.shelve(901, 0)
	for i in 4:
		assert_not_null(controller.next_customer())
	assert_null(controller.next_customer(), "four customers a day")


func test_end_of_day_summary_and_tomorrow() -> void:
	controller.start_day()
	var summary := controller.end_day()
	assert_eq(JsonValue.as_int(summary["day"]), 1)
	assert_eq(JsonValue.as_int(summary["profit"]), 0)
	assert_eq(JsonValue.as_int(summary["end_cash"]), 1000)
	assert_eq(controller.run.day, 2)
	assert_eq(controller.today.phase, DayPlan.Phase.DONE)


func test_rent_comes_out_every_seventh_day() -> void:
	controller.run.day = 7
	controller.start_day()
	var summary := controller.end_day()
	assert_eq(JsonValue.as_int(summary["rent"]), 100)
	assert_eq(controller.run.cash, 900)
	assert_eq(JsonValue.as_int(summary["rent_due_in"]), 6)


func test_scrap_job_only_when_broke_and_before_bidding() -> void:
	controller.start_day()
	assert_false(controller.can_take_scrap_job(), "$1,000 is plenty to bid with")
	controller.run.cash = 40
	assert_true(controller.can_take_scrap_job())
	assert_eq(controller.take_scrap_job(), 50)
	assert_eq(controller.run.cash, 90)
	assert_eq(controller.today.phase, DayPlan.Phase.AFTERNOON)
	assert_eq(controller.today.results.size(), 3, "the rivals had the lockers to themselves")


func test_the_snapshot_is_taken_at_the_start_of_each_day() -> void:
	var day_one: Dictionary = controller.day_start_snapshot["run"]
	assert_eq(JsonValue.as_int(day_one["day"]), 1)
	controller.start_day()
	controller.run.cash = 5
	var still_day_one: Dictionary = controller.day_start_snapshot["run"]
	assert_eq(JsonValue.as_int(still_day_one["cash"]), 1000, "mid-day changes aren't in it")
	controller.end_day()
	var day_two: Dictionary = controller.day_start_snapshot["run"]
	assert_eq(JsonValue.as_int(day_two["day"]), 2)


func test_same_seed_same_day() -> void:
	var a := RunController.new_run(Fixture.catalog(), RngStreams.new(5))
	var b := RunController.new_run(Fixture.catalog(), RngStreams.new(5))
	assert_eq(_lockers(a.start_day()), _lockers(b.start_day()))


func test_a_snapshot_replays_the_same_day() -> void:
	var streams := RngStreams.new(21)
	var first := RunController.new_run(Fixture.catalog(), streams)
	var snapshot := first.day_start_snapshot.duplicate(true)
	var original := _lockers(first.start_day())
	var resumed := RunController.from_snapshot(Fixture.catalog(), streams, snapshot)
	assert_eq(_lockers(resumed.start_day()), original)


## Swaps lot 1 for a cheap, known locker the player can easily win: a chair,
## a doll and a too-heavy anvil, opening at $20.
func _cheap_locker_as_lot_one() -> Locker:
	var day := controller.start_day()
	var items: Array[ItemInstance] = [Fixture.item(901, &"chair", 100), Fixture.item(902, &"doll", 50), Fixture.item(903, &"anvil", 200)]
	var locker := Fixture.locker(items, 100)
	locker.opening_price = 20
	day.lockers[0] = locker
	return locker


## Bids whenever the player isn't the high bidder, until the hammer falls.
func _win(auction: Auction) -> void:
	var steps := 0
	while auction.is_open() and steps < 10000:
		steps += 1
		if auction.high_bidder != Auction.PLAYER and auction.can_player_bid(auction.next_bid()):
			auction.player_raise()
		auction.advance(0.25)


func _own(item: ItemInstance) -> void:
	controller.run.items[item.uid] = item


func _lockers(day: DayPlan) -> Array:
	var described := []
	for locker in day.lockers:
		var items := []
		for item in locker.items:
			items.append(item.to_dict())
		described.append([locker.theme_id, locker.opening_price, items])
	return described
