extends GutTest
## The title screen is the Phase 0 gate: the game boots here and it works with
## a gamepad or keyboard before anyone touches the mouse.

const TITLE_SCENE: PackedScene = preload("res://scenes/ui/title_screen.tscn")

var _screen: Control


func before_each() -> void:
	_screen = TITLE_SCENE.instantiate()
	add_child_autofree(_screen)


func test_focus_starts_on_new_game() -> void:
	var new_game: Button = _screen.get_node("%NewGameButton")
	assert_true(new_game.has_focus())


func test_buttons_are_reachable_by_focus() -> void:
	var quit: Button = _screen.get_node("%QuitButton")
	assert_ne(quit.focus_mode, Control.FOCUS_NONE)


func test_new_game_shows_a_status_line() -> void:
	var new_game: Button = _screen.get_node("%NewGameButton")
	var status: Label = _screen.get_node("%StatusLabel")
	new_game.pressed.emit()
	assert_eq(status.text, tr("TITLE_COMING_SOON"))


func test_version_label_shows_the_project_version() -> void:
	var version: Label = _screen.get_node("%VersionLabel")
	assert_string_contains(version.text, str(ProjectSettings.get_setting("application/config/version")))
