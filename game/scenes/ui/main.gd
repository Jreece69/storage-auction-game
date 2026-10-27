class_name AppShell
extends Control
## The app shell and main scene. Shows one screen at a time, starting with
## the title. During a run it follows the day (see DayFlow): each stage of the
## day has its screen, so every player in a crew sees the same one. Outside a
## run, screens ask for the next one through EventBus.screen_requested.

## The screen on show.
var current: Control = null
var current_name: StringName = &""

@onready var _watching_label: Label = %WatchingLabel


func _ready() -> void:
	EventBus.screen_requested.connect(show_screen)
	EventBus.flow_changed.connect(_follow_the_day)
	Session.ended.connect(_on_session_ended)
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
	# Keep the note on top of the new screen.
	move_child(_watching_label, -1)


func _follow_the_day() -> void:
	if GameState.flow == null:
		return
	show_screen(Screens.for_stage(GameState.flow.stage))
	# Joined mid-day: watching until the next day starts.
	_watching_label.visible = not GameState.flow.crew().has(GameState.local_member)


func _on_session_ended(_reason: String) -> void:
	_watching_label.visible = false
	show_screen(Screens.TITLE)
