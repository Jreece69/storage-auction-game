class_name TitleScreen
extends Control
## The first screen. Shows the working title and the main menu. Continue
## appears when there's a save, and New game then asks to be pressed twice,
## since the new run will replace that save. Focus starts on the first button
## so a gamepad or keyboard works at once.

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _quit_button: Button = %QuitButton
@onready var _version_label: Label = %VersionLabel

var _confirming_new_game: bool = false


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_version_label.text = tr("TITLE_VERSION") % version
	_continue_button.visible = SaveManager.has_slot(SaveManager.AUTOSAVE)
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	if _continue_button.visible:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _on_continue_pressed() -> void:
	if SaveManager.load_game(SaveManager.AUTOSAVE) == OK:
		Screens.go(Screens.MAP)


func _on_new_game_pressed() -> void:
	if _continue_button.visible and not _confirming_new_game:
		_confirming_new_game = true
		_new_game_button.text = "MENU_NEW_GAME_CONFIRM"
		return
	# A new seed from the clock: the one place a run's randomness starts.
	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	GameState.new_game(entropy.randi())
	Screens.go(Screens.MAP)


func _on_quit_pressed() -> void:
	get_tree().quit()
