extends Node
## The only source of randomness in the running game. Each system draws from
## its own named stream, all derived from one master seed, so a bug report or
## a balance run can be replayed exactly from its seed.
##
## Usage: [code]Rng.stream(&"loot").randf()[/code]. Never call the global
## [code]randi()[/code] or [code]randf()[/code] in game code. The logic lives
## in [RngStreams]; this autoload holds the instance the game uses.

var streams: RngStreams = RngStreams.new()

var master_seed: int:
	get:
		return streams.master_seed


func _ready() -> void:
	# A fresh generator is seeded from the clock. A new game or a loaded save
	# replaces this seed, so it only matters before either happens.
	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	reseed(entropy.randi())


## Starts every stream over from [param new_seed].
func reseed(new_seed: int) -> void:
	streams.reseed(new_seed)


## The stream for one system, for example [code]&"auction"[/code] or
## [code]&"loot"[/code]. Drawing from one stream never shifts another.
func stream(system: StringName) -> RandomNumberGenerator:
	return streams.stream(system)


## Everything needed to resume every stream where it left off.
func to_dict() -> Dictionary:
	return streams.to_dict()


## Restores what [method to_dict] produced.
func from_dict(data: Dictionary) -> void:
	streams.from_dict(data)
