extends Node
## Player preferences, stored apart from save games in user://settings.cfg so
## starting a new game never resets them. The settings menu comes with v1.0
## (resolution, volume, rebinding, text size, colorblind-safe rarity colors).

const DEFAULT_PATH: String = "user://settings.cfg"

## Where settings live. Tests point this somewhere else so they never touch
## a player's real settings (see tests/helpers/save_sandbox.gd).
var path: String = DEFAULT_PATH

## 0.0 is silent, 1.0 is full volume.
var master_volume: float = 1.0
## The name shown to friends in co-op.
var player_name: String = ""
## The address last joined, so joining the same friend again is one press.
var last_address: String = ""


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var volume: float = config.get_value("audio", "master_volume", master_volume)
		master_volume = clampf(volume, 0.0, 1.0)
		var saved_name: String = config.get_value("co_op", "player_name", player_name)
		player_name = saved_name
		var saved_address: String = config.get_value("co_op", "last_address", last_address)
		last_address = saved_address
	apply()


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("co_op", "player_name", player_name)
	config.set_value("co_op", "last_address", last_address)
	return config.save(path)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
