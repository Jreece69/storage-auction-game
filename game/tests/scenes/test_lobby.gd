extends GutTest
## The lobby: a name first, then host or join. Hosting seats you as player 1
## and shows the address to give friends; the host starts the day.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const LOBBY_SCENE: PackedScene = preload("res://scenes/ui/lobby.tscn")

var lobby: Lobby


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	Settings.player_name = ""
	Settings.last_address = ""
	lobby = LOBBY_SCENE.instantiate()
	add_child_autofree(lobby)


func after_each() -> void:
	Session.leave()
	GameState.end_run()


func test_a_name_comes_first() -> void:
	assert_true(_edit("%NameEdit").has_focus())
	_press("%HostButton")
	assert_false(Session.is_online(), "no name, no game")
	assert_eq(_label("%MessageLabel").text, tr("LOBBY_NEED_NAME"))


func test_hosting_seats_you_and_shows_your_address() -> void:
	_edit("%NameEdit").text = "Jack"
	lobby.host()
	assert_true(Session.is_online())
	assert_eq(Settings.player_name, "Jack", "the name is remembered")
	assert_true(_panel("%RoomPanel").visible)
	assert_string_contains(_label("%StatusLabel").text, str(Session.DEFAULT_PORT))
	var crew: VBoxContainer = lobby.get_node("%CrewList")
	assert_eq(crew.get_child_count(), 1)
	assert_true(_button("%NewGameButton").has_focus())


func test_joining_needs_an_address() -> void:
	_edit("%NameEdit").text = "Sam"
	_press("%JoinButton")
	assert_false(Session.is_online())
	assert_eq(_label("%MessageLabel").text, tr("LOBBY_NEED_ADDRESS"))


func test_joining_remembers_the_address() -> void:
	_edit("%NameEdit").text = "Sam"
	_edit("%AddressEdit").text = "127.0.0.1"
	_press("%JoinButton")
	assert_true(Session.is_client())
	assert_eq(Settings.last_address, "127.0.0.1")
	assert_eq(_label("%StatusLabel").text, tr("LOBBY_CONNECTING") % "127.0.0.1")


func test_starting_a_new_game_from_the_lobby() -> void:
	_edit("%NameEdit").text = "Jack"
	lobby.host()
	_press("%NewGameButton")
	assert_true(GameState.has_run())
	assert_eq(GameState.flow.stage, DayFlow.Stage.MAP)
	assert_eq(GameState.flow.crew(), [Crew.HOST] as Array[StringName])


func test_back_leaves_the_session() -> void:
	_edit("%NameEdit").text = "Jack"
	lobby.host()
	watch_signals(EventBus)
	_press("%BackButton")
	assert_false(Session.is_online())
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.TITLE])


func test_a_session_that_ends_shows_why() -> void:
	_edit("%NameEdit").text = "Sam"
	_edit("%AddressEdit").text = "127.0.0.1"
	_press("%JoinButton")
	Session.ended.emit("SESSION_HOST_LEFT")
	assert_true(_panel("%ChoicePanel").visible)
	assert_eq(_label("%MessageLabel").text, tr("SESSION_HOST_LEFT"))


func _press(path: String) -> void:
	var button := _button(path)
	assert_true(button.is_visible_in_tree(), "%s is showing" % path)
	button.pressed.emit()


func _button(path: String) -> Button:
	return lobby.get_node(path) as Button


func _label(path: String) -> Label:
	return lobby.get_node(path) as Label


func _edit(path: String) -> LineEdit:
	return lobby.get_node(path) as LineEdit


func _panel(path: String) -> Control:
	return lobby.get_node(path) as Control
