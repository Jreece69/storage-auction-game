extends Node
## Plays day 1 through the real app, the way a player would, and saves a
## screenshot of every screen to $SHOT_DIR. Run it with
## tools/screenshots.sh. It wins the first locker (with extra cash so any
## seed works), sits out the rest, sells what it can, and closes up.

var _app: AppShell
var _dir: String


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	SaveManager.save_dir = "user://shot_saves/"
	var packed: PackedScene = load("res://scenes/ui/main.tscn")
	_app = packed.instantiate()
	add_child(_app)
	_run.call_deferred()


func _run() -> void:
	await _shot("01_title")
	GameState.new_game(2026)
	Screens.go(Screens.MAP)
	await _shot("02_map")
	_press("%AuctionButton")
	await _shot("03_peek")
	var yard := _app.current as AuctionYard
	var controller := GameState.controller
	controller.run.cash = 5000
	EventBus.cash_changed.emit(controller.run.cash)
	_press("%StartButton")
	yard.tick(1.4)
	_press("%RaiseButton")
	yard.tick(1.0)
	await _shot("04_bidding")
	for i in 5000:
		if yard.stage != AuctionYard.Stage.BIDDING:
			break
		if not _button("%RaiseButton").disabled:
			_press("%RaiseButton")
		yard.tick(0.25)
	await _shot("05_result")
	_press("%ResultButton")
	yard.tick(AuctionYard.REVEAL_INTERVAL * 2.5)
	await _shot("06_reveal_partway")
	yard.reveal_all()
	await _shot("07_reveal")
	_press("%LoadButton")
	await _shot("08_haul")
	_press("%DriveButton")
	_press("%SkipButton")
	await _shot("09_skipped")
	_press("%ResultButton")
	_press("%SkipButton")
	_press("%ResultButton")
	await _shot("10_morning_done")
	_press("%ToShopButton")
	await _shot("11_shop_back_room")
	var shop := _app.current as ShopScreen
	for uid in controller.run.backroom_uids():
		shop.shelve(uid)
	await _shot("12_shop_shelved")
	_press("%OpenDoorsButton")
	await _shot("13_customer")
	for i in 6:
		if shop.customer != null and shop.customer.is_offering():
			_press("%AcceptButton")
			await _shot("14_sold_%d" % i)
		if _button("%NextCustomerButton").disabled:
			break
		_press("%NextCustomerButton")
	await _shot("15_last_customer")
	_press("%CloseUpButton")
	await _shot("16_summary")
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	get_tree().quit()


func _shot(shot_name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(_dir.path_join(shot_name + ".png"))
	print("shot ", shot_name, " ", image.get_size())


func _press(path: String) -> void:
	var button := _button(path)
	if button.disabled or not button.is_visible_in_tree():
		push_error("can't press %s" % path)
		return
	button.pressed.emit()


func _button(path: String) -> Button:
	return _app.current.get_node(path) as Button
