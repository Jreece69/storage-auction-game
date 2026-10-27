class_name AppShell
extends Control
## The app shell and main scene. Shows one screen at a time, starting with
## the title. During a run it follows the day (see DayFlow): each stage of the
## day has its screen, so every player in a crew sees the same one. Outside a
## run, screens ask for the next one through EventBus.screen_requested.

## The screen on show.
var current: Control = null
var current_name: StringName = &""


func _ready() -> void:
	EventBus.screen_requested.connect(show_screen)
	EventBus.flow_changed.connect(_follow_the_day)
	show_screen(Screens.TITLE)


func _notification(what: int) -> void:
	# Closing the window keeps the run, as it stood at the start of today.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.has_run():
		SaveManager.save_game(SaveManager.AUTOSAVE)


func show_screen(screen: StringName) -> void:
	if screen == current_name and current != null:
		return
	if current != null:
		# Deferred, because the old screen is usually mid-callback.
		current.queue_free()
	var packed: PackedScene = load(Screens.path(screen))
	current = packed.instantiate()
	current_name = screen
	add_child(current)


func _follow_the_day() -> void:
	if GameState.flow != null:
		show_screen(Screens.for_stage(GameState.flow.stage))
