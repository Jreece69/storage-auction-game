extends GutTest
## The game boots to the title screen, which works with a gamepad or keyboard
## before anyone touches the mouse, starts new runs, and picks a saved one
## back up.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	watch_signals(EventBus)


func after_each() -> void:
	GameState.end_run()


func test_focus_starts_on_new_game_without_a_save() -> void:
	var screen := _open()
	var continue_button: Button = screen.get_node("%ContinueButton")
	var new_game: Button = screen.get_node("%NewGameButton")
	assert_false(continue_button.visible)
	assert_true(new_game.has_focus())


func test_buttons_are_reachable_by_focus() -> void:
	var quit: Button = _open().get_node("%QuitButton")
	assert_ne(quit.focus_mode, Control.FOCUS_NONE)


func test_new_game_starts_a_run_and_goes_to_the_map() -> void:
	var new_game: Button = _open().get_node("%NewGameButton")
	new_game.pressed.emit()
	assert_true(GameState.has_run())
	assert_eq(GameState.day, 1)
	assert_eq(GameState.flow.stage, DayFlow.Stage.MAP, "the day starts on the map")
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.MAP])


func test_continue_appears_with_a_save_and_resumes_it() -> void:
	_save_a_run_on_day(3)
	var screen := _open()
	var continue_button: Button = screen.get_node("%ContinueButton")
	assert_true(continue_button.visible)
	assert_true(continue_button.has_focus(), "a returning player lands on Continue")
	continue_button.pressed.emit()
	assert_eq(GameState.day, 3)
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.MAP])


func test_new_game_over_a_save_asks_twice() -> void:
	_save_a_run_on_day(3)
	var new_game: Button = _open().get_node("%NewGameButton")
	new_game.pressed.emit()
	assert_false(GameState.has_run(), "the first press only asks")
	assert_eq(new_game.text, "MENU_NEW_GAME_CONFIRM")
	new_game.pressed.emit()
	assert_eq(GameState.day, 1)


func test_version_label_shows_the_project_version() -> void:
	var version: Label = _open().get_node("%VersionLabel")
	assert_string_contains(version.text, str(ProjectSettings.get_setting("application/config/version")))


func _open() -> Control:
	var screen: Control = TITLE_SCENE.instantiate()
	add_child_autofree(screen)
	return screen


func _save_a_run_on_day(day: int) -> void:
	GameState.new_game(5)
	for i in day - 1:
		GameState.controller.start_day()
		GameState.controller.end_day()
	SaveManager.save_game(SaveManager.AUTOSAVE)
	GameState.end_run()
