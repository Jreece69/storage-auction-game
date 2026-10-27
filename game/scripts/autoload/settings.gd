extends Node
## Player preferences, stored apart from save games in user://settings.cfg so
## starting a new game never resets them. Phase 4 adds the settings menu
## (resolution, volume, rebinding, text size, colorblind-safe rarity colors).

const PATH: String = "user://settings.cfg"

## 0.0 is silent, 1.0 is full volume.
var master_volume: float = 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	apply()


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	return config.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))
