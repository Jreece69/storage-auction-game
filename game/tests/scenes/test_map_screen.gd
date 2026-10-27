extends GutTest
## The start of each day: the numbers that matter, the way to the auction,
## the scrap job for a broke player, and saving.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const MAP_SCENE: PackedScene = preload("res://scenes/map/map_screen.tscn")


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	GameState.new_game(11)
	watch_signals(EventBus)


func after_each() -> void:
	GameState.end_run()


func test_shows_the_day_cash_and_rent() -> void:
	var screen := _open()
	var economy := Content.catalog.economy
	assert_eq((screen.get_node("%DayLabel") as Label).text, tr("MAP_DAY") % 1)
	assert_eq((screen.get_node("%CashLabel") as Label).text, tr("UI_CASH") % Money.format(economy.starting_cash))
	var rent := (screen.get_node("%RentLabel") as Label).text
	assert_eq(rent, tr("MAP_RENT_IN") % [Money.format(economy.rent_amount), economy.rent_every_days - 1])


func test_opening_the_map_rolls_the_day() -> void:
	_open()
	assert_not_null(GameState.controller.today)
	assert_eq(GameState.controller.today.lockers.size(), GameState.controller.zone().lockers_per_day)


func test_auction_button_has_focus_and_goes_to_the_auction() -> void:
	var auction: Button = _open().get_node("%AuctionButton")
	assert_true(auction.has_focus())
	auction.pressed.emit()
	assert_eq(GameState.flow.stage, DayFlow.Stage.PEEK)


func test_skipping_to_the_shop_gives_the_lockers_to_the_rivals() -> void:
	var shop: Button = _open().get_node("%ShopButton")
	shop.pressed.emit()
	var today := GameState.controller.today
	assert_eq(today.phase, DayPlan.Phase.AFTERNOON)
	assert_eq(today.results.size(), today.lockers.size())
	assert_eq(GameState.flow.stage, DayFlow.Stage.SHOP)


func test_no_scrap_job_while_there_is_money() -> void:
	var scrap: Button = _open().get_node("%ScrapJobButton")
	assert_false(scrap.visible)


func test_a_broke_player_is_offered_a_scrap_job() -> void:
	GameState.controller.run.cash = 20
	var screen := _open()
	var scrap: Button = screen.get_node("%ScrapJobButton")
	assert_true(scrap.visible)
	assert_true(scrap.has_focus())
	scrap.pressed.emit()
	assert_eq(GameState.cash, 20 + Content.catalog.economy.scrap_job_pay)
	assert_eq(GameState.flow.stage, DayFlow.Stage.SHOP)


func test_save_and_quit_writes_the_save_and_returns_to_the_title() -> void:
	var save_quit: Button = _open().get_node("%SaveQuitButton")
	save_quit.pressed.emit()
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE))
	assert_false(GameState.has_run())
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.TITLE])


func _open() -> Control:
	var screen: Control = MAP_SCENE.instantiate()
	add_child_autofree(screen)
	return screen
