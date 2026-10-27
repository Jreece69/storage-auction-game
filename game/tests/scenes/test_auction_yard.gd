extends GutTest
## The auction yard plays the morning: the peek shows this player's third of
## the locker, the bidding follows the auction's events, and a win goes
## through the reveal and the van into the back room.

const YARD_SCENE: PackedScene = preload("res://scenes/auction/auction_yard.tscn")
## Enough screen time for any auction to finish.
const MAX_TICKS: int = 5000
const TICK: float = 0.25

var yard: AuctionYard
var controller: RunController


func before_each() -> void:
	GameState.new_game(21)
	controller = GameState.controller
	watch_signals(EventBus)


func after_each() -> void:
	GameState.local_member = Crew.HOST
	GameState.end_run()


func test_the_peek_shows_this_players_third_of_the_first_locker() -> void:
	_open()
	var locker := controller.today.lockers[0]
	assert_eq(yard.stage, AuctionYard.Stage.PEEK)
	assert_eq(_peek_lines(), _peek_lines_for(locker, 0))
	assert_eq(_label("%HiddenLabel").text, tr("AUCTION_HIDDEN") % locker.hidden_count_for(0))
	assert_string_contains(_label("%LotLabel").text, tr("AUCTION_LOT") % [1, controller.today.lockers.size(), tr(controller.catalog.themes[locker.theme_id].name_key)])
	assert_true(_button("%StartButton").has_focus())


func test_each_crew_seat_peeks_its_own_third() -> void:
	GameState.local_member = &"p3"
	_open()
	assert_eq(_peek_lines(), _peek_lines_for(controller.today.lockers[0], 2))


func test_bidding_starts_when_the_peek_runs_out() -> void:
	_open()
	yard.tick(controller.catalog.economy.auction.peek_seconds - 1.0)
	assert_eq(yard.stage, AuctionYard.Stage.PEEK)
	yard.tick(1.5)
	assert_eq(yard.stage, AuctionYard.Stage.BIDDING)
	assert_true(_button("%RaiseButton").has_focus())


func test_raise_bids_the_opening_price() -> void:
	_open_bidding()
	var auction := yard.current_auction()
	_press("%RaiseButton")
	assert_eq(auction.high_bidder, Crew.HOST)
	assert_eq(auction.price, auction.opening_price)
	assert_eq(_label("%HighBidderLabel").text, tr("AUCTION_HIGH_BIDDER") % tr("UI_YOU"))
	assert_true(_button("%RaiseButton").disabled, "nobody raises their own bid")
	assert_string_contains(_label("%FeedLabel").text, tr("FEED_YOU_BID") % Money.format(auction.opening_price))


func test_the_countdown_bar_runs_down() -> void:
	_open_bidding()
	_press("%RaiseButton")
	var bar: ProgressBar = yard.get_node("%CountdownBar")
	assert_almost_eq(bar.value, 1.0, 0.001)
	yard.tick(0.1)
	assert_lt(bar.value, 1.0)


func test_passing_lets_the_rivals_settle_it() -> void:
	_open_bidding()
	_press("%PassButton")
	assert_true(_button("%PassButton").disabled)
	_tick_while(AuctionYard.Stage.BIDDING)
	assert_eq(yard.stage, AuctionYard.Stage.RESULT)
	var locker := controller.today.lockers[0]
	assert_true(controller.today.is_settled(locker))
	assert_false(controller.crew.has(controller.today.results[locker.lot_number]))
	assert_eq(_button("%ResultButton").text, tr("RESULT_NEXT"))
	assert_true(_button("%ResultButton").has_focus())


func test_sitting_a_locker_out_moves_on_to_the_next() -> void:
	_open()
	_press("%SkipButton")
	assert_eq(yard.stage, AuctionYard.Stage.RESULT)
	assert_true(controller.today.is_settled(controller.today.lockers[0]))
	_press("%ResultButton")
	assert_eq(yard.stage, AuctionYard.Stage.PEEK)
	assert_eq(_peek_lines(), _peek_lines_for(controller.today.lockers[1], 0))


func test_a_win_is_paid_for_and_announced() -> void:
	_open_bidding()
	var cash_before := GameState.cash
	var price := _win()
	assert_eq(_label("%ResultLabel").text, tr("RESULT_WON") % Money.format(price))
	assert_eq(GameState.cash, cash_before - price)
	assert_eq(_label("%CashLabel").text, tr("UI_CASH") % Money.format(GameState.cash))
	assert_eq(_button("%ResultButton").text, tr("RESULT_OPEN"))


func test_the_reveal_brings_items_out_one_at_a_time() -> void:
	_open_bidding()
	_win()
	_press("%ResultButton")
	assert_eq(yard.stage, AuctionYard.Stage.REVEAL)
	var shown: VBoxContainer = yard.get_node("%RevealItems")
	assert_eq(shown.get_child_count(), 0)
	yard.tick(AuctionYard.REVEAL_INTERVAL + 0.01)
	assert_eq(shown.get_child_count(), 1)
	assert_true(_button("%LoadButton").disabled, "nothing to load until it's all out")
	_press("%RevealSkipButton")
	assert_eq(shown.get_child_count(), controller.today.lockers[0].items.size())
	assert_false(_button("%LoadButton").disabled)
	assert_true(_button("%LoadButton").has_focus())


func test_driving_home_takes_the_load_to_the_back_room() -> void:
	_to_the_van()
	var plan := yard.haul_plan()
	var loaded := plan.selected_items()
	var left := plan.left_behind()
	assert_gt(loaded.size(), 0, "something fits in the van")
	var scrap := plan.scrap_value(controller.today.lockers[0].junk_weight)
	var cash_before := GameState.cash
	_press("%DriveButton")
	for item in loaded:
		assert_true(controller.run.items.has(item.uid))
	for item in left:
		assert_false(controller.run.items.has(item.uid))
	assert_eq(GameState.cash, cash_before + scrap)
	assert_eq(yard.stage, AuctionYard.Stage.PEEK, "on to the next locker")


func test_unloading_an_item_leaves_it_behind() -> void:
	_to_the_van()
	var plan := yard.haul_plan()
	var item := plan.selected_items()[0]
	assert_true(yard.click_haul_row(item.uid))
	assert_false(plan.is_selected(item.uid))
	_press("%DriveButton")
	assert_false(controller.run.items.has(item.uid))


func test_an_item_that_wont_fit_stays_out() -> void:
	_to_the_van()
	var plan := yard.haul_plan()
	if plan.left_behind().is_empty():
		pass_test("everything fit in this locker")
		return
	var item := plan.left_behind()[0]
	assert_false(yard.click_haul_row(item.uid))
	assert_false(plan.is_selected(item.uid))
	assert_eq(_label("%HaulHintLabel").text, tr("HAUL_NO_FIT"))


func test_after_the_last_locker_it_is_off_to_the_shop() -> void:
	_open()
	var lots := controller.today.lockers.size()
	for i in lots:
		_press("%SkipButton")
		_press("%ResultButton")
	assert_eq(yard.stage, AuctionYard.Stage.DONE)
	assert_eq(_label("%DoneCountLabel").text, tr("AUCTION_MORNING_COUNT") % [0, lots])
	assert_true(_button("%ToShopButton").has_focus())
	_press("%ToShopButton")
	assert_eq(controller.today.phase, DayPlan.Phase.AFTERNOON)
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.SHOP])


func test_coming_back_after_the_morning_shows_it_is_over() -> void:
	controller.start_day()
	controller.start_afternoon()
	_open()
	assert_eq(yard.stage, AuctionYard.Stage.DONE)


func _open() -> void:
	yard = YARD_SCENE.instantiate()
	add_child_autofree(yard)


## Opens the yard with deep pockets and goes straight to the bidding.
func _open_bidding() -> void:
	controller.run.cash = 100000
	_open()
	_press("%StartButton")
	assert_eq(yard.stage, AuctionYard.Stage.BIDDING)


## Raises whenever outbid until the hammer falls. Returns the price paid.
func _win() -> int:
	var auction := yard.current_auction()
	for i in MAX_TICKS:
		if yard.stage != AuctionYard.Stage.BIDDING:
			break
		if not _button("%RaiseButton").disabled:
			_press("%RaiseButton")
		yard.tick(TICK)
	assert_eq(yard.stage, AuctionYard.Stage.RESULT)
	assert_true(auction.crew_won(), "deep pockets win")
	return auction.price


func _to_the_van() -> void:
	_open_bidding()
	_win()
	_press("%ResultButton")
	yard.reveal_all()
	_press("%LoadButton")
	assert_eq(yard.stage, AuctionYard.Stage.HAUL)


func _tick_while(stage: AuctionYard.Stage) -> void:
	for i in MAX_TICKS:
		if yard.stage != stage:
			return
		yard.tick(TICK)


func _peek_lines() -> Array[String]:
	var lines: Array[String] = []
	for child in yard.get_node("%PeekItems").get_children():
		lines.append((child as Label).text)
	return lines


func _peek_lines_for(locker: Locker, seat: int) -> Array[String]:
	var lines: Array[String] = []
	for item in locker.visible_items_for(seat):
		lines.append(UiKit.fmt("PEEK_ITEM", [UiKit.item_name(item.def_id), UiKit.rarity_name(controller.pricing.def_of(item).rarity)]))
	return lines


## Presses a button the way a player can: only when it's showing and enabled.
func _press(path: String) -> void:
	var button := _button(path)
	assert_true(button.is_visible_in_tree(), "%s is showing" % path)
	assert_false(button.disabled, "%s is enabled" % path)
	button.pressed.emit()


func _button(path: String) -> Button:
	return yard.get_node(path) as Button


func _label(path: String) -> Label:
	return yard.get_node(path) as Label
