extends Control
## The first screen. Shows the working title and the main menu.
## Focus starts on the first button so a gamepad or keyboard works at once.

@onready var _new_game_button: Button = %NewGameButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel
@onready var _version_label: Label = %VersionLabel


func _ready() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_version_label.text = tr("TITLE_VERSION") % version
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	# Phase 1 replaces this with the first morning's auctions.
	_status_label.text = tr("TITLE_COMING_SOON")


func _on_quit_pressed() -> void:
	get_tree().quit()
