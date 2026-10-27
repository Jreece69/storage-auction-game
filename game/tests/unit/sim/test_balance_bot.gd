extends GutTest
## The balance sim's bot plays whole days through the real rules, the same
## way on the same seed, sizes lockers up from its peek, keeps the rent back,
## and reads the shark.

const Fixture := preload("res://tests/helpers/fixture.gd")

var catalog: Catalog


func before_each() -> void:
	catalog = Fixture.catalog()


func test_a_day_ends_on_the_next_morning() -> void:
	var bot := _bot(1)
	var summary := bot.play_day()
	assert_eq(JsonValue.as_int(summary["day"]), 1)
	assert_eq(bot.controller.run.day, 2)
	assert_eq(JsonValue.as_int(summary["lockers_won"]) + JsonValue.as_int(summary["lockers_lost"]), 3)


func test_the_same_seed_plays_the_same_week() -> void:
	assert_eq(_week(5), _week(5))


func test_a_month_of_play_keeps_the_books_straight() -> void:
	# Cash only moves through the day's ledger.
	var bot := _bot(9)
	bot.reads_rivals = true
	bot.jumps_at_skittish = true
	for day in 30:
		var cash_before := bot.controller.run.cash
		var summary := bot.play_day()
		assert_eq(bot.controller.run.cash, cash_before + JsonValue.as_int(summary["profit"]), "day %d" % (day + 1))


func test_the_estimate_scales_what_it_sees_to_the_whole_locker() -> void:
	var bot := _bot(1)
	# Fixture chairs are $100 apiece; the bot sees one of three, plus 100 lb of
	# junk at $0.10 a pound.
	var locker := Fixture.locker([Fixture.item(1, &"chair", 100), Fixture.item(2, &"chair", 100), Fixture.item(3, &"chair", 100)] as Array[ItemInstance], 100)
	var seen := PackedInt32Array([1])
	locker.visible_sets[0] = seen
	assert_eq(bot.estimate(locker), 310)


func test_rent_money_is_kept_back_when_rent_is_close() -> void:
	var bot := _bot(1)
	var run := bot.controller.run
	run.cash = 500
	run.day = 1
	assert_eq(bot.spendable(), 500, "rent is six days away")
	run.day = 6
	assert_eq(bot.spendable(), 500 - catalog.economy.rent_amount, "rent is due tomorrow night")


func test_reading_the_shark() -> void:
	var bot := _bot(1)
	var bot_controller := bot.controller
	bot_controller.start_day()
	var auction := bot_controller.open_auction(bot_controller.today.lockers[0])
	var shark := _bidder(auction, &"shark")
	auction.price = 140
	auction.high_bidder = &"rook"
	var dropped_at: Dictionary[StringName, int] = {}
	assert_almost_eq(bot.read(auction, dropped_at), 200.0, 0.01, "still in at $140: worth at least $140 / 0.7")
	shark.folded = true
	dropped_at[&"shark"] = 210
	assert_almost_eq(bot.read(auction, dropped_at), 300.0, 0.01, "dropped out rather than bid $210: worth about $210 / 0.7")


func _bot(run_seed: int) -> BalanceBot:
	return BalanceBot.new(RunController.new_run(catalog, RngStreams.new(run_seed)))


func _week(run_seed: int) -> Array:
	var bot := _bot(run_seed)
	var days := []
	for day in 7:
		days.append(bot.play_day())
	return [days, bot.controller.run.to_dict()]


func _bidder(auction: Auction, rival_id: StringName) -> RivalBidder:
	for bidder in auction.bidders:
		if bidder.id == rival_id:
			return bidder
	return null
