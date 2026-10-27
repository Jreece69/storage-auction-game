extends Node
## The game's content, loaded once when the game starts. A data mistake is
## reported as an error at boot, which fails the boot check and the export
## smoke test, so bad data never reaches a build.

var catalog: Catalog


func _init() -> void:
	# Loaded in _init so it is ready before any other autoload's _ready.
	catalog = Catalog.load_from()
	for problem in catalog.errors:
		push_error("Content: " + problem)
