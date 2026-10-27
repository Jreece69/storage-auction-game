extends SceneTree
## Starts tools/screenshots/play_a_day.gd once the autoloads exist. A script
## passed to Godot with -s is compiled before the autoloads are registered,
## so it can't name them itself.


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var script := load(OS.get_environment("SHOT_RUNNER")) as GDScript
	var runner: Node = script.new()
	root.add_child(runner)
