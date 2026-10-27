extends Node
## Plays a co-op day through the real screens on two copies of the game, a
## host ($COOP_ROLE=host) and a friend (join), connected through the lobby
## over ENet on localhost, and saves screenshots from each side to $SHOT_DIR.
## Run it with tools/screenshots.sh --coop. Started by tools/boot_runner.gd.
##
## Both press real buttons: they bid against each other on the first locker
## (the host, with deep pockets, wins), sit out the rest, sell at their own
## counters and close up together.

const TIMEOUT_SECONDS: float = 120.0

var _app: AppShell
var _dir: String
var _host: bool
var _elapsed := 0.0
var _busy := false
var _done := false
var _raises := 0
var _shots_taken: Dictionary[String, bool] = {}


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	_host = OS.get_environment("COOP_ROLE") == "host"
	SaveManager.save_dir = "user://shot_saves_%s/" % ("host" if _host else "friend")
	Settings.path = SaveManager.save_dir + "settings.cfg"
	var packed: PackedScene = load("res://scenes/ui/main.tscn")
	_app = packed.instantiate()
	add_child(_app)
	_start.call_deferred()


func _start() -> void:
	_busy = true
	await _shot("01_title")
	_press("%FriendsButton")
	await _frames(2)
	(_app.current.get_node("%NameEdit") as LineEdit).text = "Jack" if _host else "Sam"
	if _host:
		_press("%HostButton")
	else:
		await get_tree().create_timer(1.5).timeout
		(_app.current.get_node("%AddressEdit") as LineEdit).text = "127.0.0.1"
		_press("%JoinButton")
	_busy = false


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS and not _done:
		_done = true
		push_error("co-op screenshots timed out (%s)" % ("host" if _host else "friend"))
		get_tree().quit(1)
	if _busy or _done:
		return
	_busy = true
	await _step()
	_busy = false


## One look at the screen and at most one press, like a player.
func _step() -> void:
	var flow := GameState.flow
	if flow == null:
		if _app.current_name == Screens.LOBBY and Session.seated().size() >= 2:
			await _shot_once("02_lobby")
			if _host:
				await _frames(10)
				_press("%NewGameButton")
		return
	var me := GameState.local_member
	match flow.stage:
		DayFlow.Stage.MAP:
			await _shot_once("03_map")
			if _host:
				flow.controller.run.cash = 5000
				EventBus.cash_changed.emit(5000)
				_press("%AuctionButton")
		DayFlow.Stage.PEEK:
			if flow.locker.lot_number == 1:
				await _shot_once("04_peek")
				_press_if_enabled("%StartButton")
				await _shot_once("05_peek_waiting")
			else:
				_press_if_enabled("%SkipButton")
		DayFlow.Stage.BIDDING:
			var auction := flow.auction
			if auction.high_bidder == me or auction.crew_out.has(me):
				return
			if _host or _raises < 2:
				_raises += 1
				_press_if_enabled("%RaiseButton")
				await _frames(20)
				if _raises == 3:
					await _shot_once("06_bidding")
			else:
				await _shot_once("06_bidding")
				_press_if_enabled("%PassButton")
		DayFlow.Stage.RESULT:
			if flow.locker.lot_number == 1:
				await _shot_once("07_result")
			if _host:
				await _frames(30)
				_press_if_enabled("%ResultButton")
		DayFlow.Stage.REVEAL:
			if _host:
				_press_if_enabled("%RevealSkipButton")
				await _frames(10)
				await _shot_once("08_reveal")
				_press_if_enabled("%LoadButton")
			else:
				await _shot_once("08_reveal")
		DayFlow.Stage.HAUL:
			await _shot_once("09_haul")
			_press_if_enabled("%DriveButton")
			await _shot_once("10_haul_waiting")
		DayFlow.Stage.MORNING_DONE:
			if _host:
				_press_if_enabled("%ToShopButton")
		DayFlow.Stage.SHOP:
			await _shop(flow, me)
		DayFlow.Stage.SUMMARY:
			await _frames(20)
			await _shot_once("14_summary")
			_done = true
			print("Co-op screenshots done (%s)." % ("host" if _host else "friend"))
			await get_tree().create_timer(3.0 if _host else 0.5).timeout
			get_tree().quit()


func _shop(flow: DayFlow, me: StringName) -> void:
	var shop := _app.current as ShopScreen
	if shop == null:
		return
	var run := flow.controller.run
	if _host and not run.backroom_uids().is_empty():
		shop.shelve(run.backroom_uids()[0])
		await _frames(5)
		return
	if run.backroom_uids().is_empty() and not _shots_taken.has("11_shop"):
		await _frames(10)
		await _shot_once("11_shop")
	if shop.mode == ShopScreen.Mode.STOCKING:
		if flow.more_customers():
			_press_if_enabled("%OpenDoorsButton")
		else:
			_press_if_enabled("%CloseUpButton")
			await _shot_once("13_closing_waiting")
		return
	var counter := flow.counter_of(me)
	if counter.is_busy():
		await _shot_once("12_counter")
		_press_if_enabled("%AcceptButton")
		await _frames(10)
	elif flow.more_customers():
		_press_if_enabled("%NextCustomerButton")
		await _frames(10)
	else:
		_press_if_enabled("%CloseUpButton")
		await _shot_once("13_closing_waiting")


func _shot_once(shot_name: String) -> void:
	if _shots_taken.has(shot_name):
		return
	_shots_taken[shot_name] = true
	await _shot(shot_name)


func _shot(shot_name: String) -> void:
	await _frames(3)
	var image := get_viewport().get_texture().get_image()
	var file := "%s_%s.png" % ["host" if _host else "friend", shot_name]
	image.save_png(_dir.path_join(file))
	print("shot ", file)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _press(path: String) -> void:
	var button := _app.current.get_node(path) as Button
	button.pressed.emit()


func _press_if_enabled(path: String) -> void:
	var button := _app.current.get_node_or_null(path) as Button
	if button != null and button.is_visible_in_tree() and not button.disabled:
		button.pressed.emit()
