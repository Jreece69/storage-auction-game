extends SceneTree
## Starts the script named by $RUNNER (a Node) once the autoloads exist. A
## script passed to Godot with -s is compiled before the autoloads are
## registered, so it can't name them itself. Used by tools/screenshots.sh,
## tools/export_smoke.sh and tools/coop_smoke.sh.


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var script := load(OS.get_environment("RUNNER")) as GDScript
	var runner: Node = script.new()
	root.add_child(runner)
