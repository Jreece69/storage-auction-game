extends GutTest
## The whole app as a player runs it: the shell starts on the title and
## swaps screens as the day moves on, from the map through the auction and
## the shop to the next morning.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/ui/main.tscn")
## Enough screen time for any auction to finish.
const MAX_TICKS: int = 5000

var app: AppShell


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	app = MAIN_SCENE.instantiate()
	add_child_autofree(app)


func after_each() -> void:
	GameState.end_run()


func test_the_app_starts_on_the_title() -> void:
	_assert_showing(Screens.TITLE)


func test_a_screen_request_swaps_the_screen() -> void:
	var title := app.current
	GameState.new_game(1)
	Screens.go(Screens.MAP)
	_assert_showing(Screens.MAP)
	assert_true(title.is_queued_for_deletion(), "the old screen goes")


func test_a_full_day_through_the_app() -> void:
	# A fixed seed keeps the day the same on every run; the title's own New
	# game button is covered in test_title_screen.
	GameState.new_game(2026)
	var controller := GameState.controller
	controller.run.cash = 100000
	Screens.go(Screens.MAP)
	_press("%AuctionButton")
	_assert_showing(Screens.AUCTION)

	# Win the first locker, unload it into the back room, sit out the rest.
	var yard := app.current as AuctionYard
	_press("%StartButton")
	for i in MAX_TICKS:
		if yard.stage != AuctionYard.Stage.BIDDING:
			break
		if not _button("%RaiseButton").disabled:
			_press("%RaiseButton")
		yard.tick(0.25)
	assert_true(controller.crew.has(controller.today.results[1]), "won the first locker")
	_press("%ResultButton")
	yard.reveal_all()
	_press("%LoadButton")
	_press("%DriveButton")
	for lot in controller.today.lockers.size():
		if yard.stage == AuctionYard.Stage.DONE:
			break
		_press("%SkipButton")
		_press("%ResultButton")
	assert_eq(yard.stage, AuctionYard.Stage.DONE)
	assert_gt(controller.run.items.size(), 0, "the haul made it home")
	_press("%ToShopButton")
	_assert_showing(Screens.SHOP)

	# Put everything out, then take every offer.
	var shop := app.current as ShopScreen
	for uid in controller.run.backroom_uids():
		shop.shelve(uid)
	_press("%OpenDoorsButton")
	for i in controller.catalog.economy.shop.customers_per_day:
		if shop.customer != null and shop.customer.is_offering():
			_press("%AcceptButton")
		if _button("%NextCustomerButton").disabled:
			break
		_press("%NextCustomerButton")
	var sold := controller.today.ledger.items_sold
	_press("%CloseUpButton")
	_assert_showing(Screens.SUMMARY)
	assert_eq(JsonValue.as_int(controller.last_summary["items_sold"]), sold)
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE), "the day was saved")

	_press("%NextDayButton")
	_assert_showing(Screens.MAP)
	assert_eq(GameState.day, 2)


func _assert_showing(screen: StringName) -> void:
	assert_eq(app.current.scene_file_path, Screens.path(screen))


## Presses a button on the current screen, the way a player can.
func _press(path: String) -> void:
	var button := _button(path)
	assert_true(button.is_visible_in_tree(), "%s is showing" % path)
	assert_false(button.disabled, "%s is enabled" % path)
	button.pressed.emit()


func _button(path: String) -> Button:
	return app.current.get_node(path) as Button
