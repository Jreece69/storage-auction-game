class_name RngStreams
extends RefCounted
## Seeded random streams, one per system, all derived from one master seed,
## so a bug report or a balance run can be replayed exactly from its seed.
##
## The Rng autoload wraps one of these for the running game. The balance sim
## and tests make their own, so they never disturb the game's sequence.

var master_seed: int = 0

var _streams: Dictionary[StringName, RandomNumberGenerator] = {}


func _init(new_seed: int = 0) -> void:
	reseed(new_seed)


## Starts every stream over from [param new_seed].
func reseed(new_seed: int) -> void:
	master_seed = new_seed
	_streams.clear()


## The stream for one system, for example [code]&"auction"[/code] or
## [code]&"loot"[/code]. Drawing from one stream never shifts another.
func stream(system: StringName) -> RandomNumberGenerator:
	if not _streams.has(system):
		var rng := RandomNumberGenerator.new()
		rng.seed = derive_seed(master_seed, system)
		_streams[system] = rng
	return _streams[system]


## Everything needed to resume every stream where it left off.
## Seeds and states are written as strings: JSON numbers are doubles and
## silently lose precision above 2^53, which would break replays.
func to_dict() -> Dictionary:
	var states: Dictionary = {}
	for system: StringName in _streams:
		states[String(system)] = str(_streams[system].state)
	return {"master_seed": str(master_seed), "streams": states}


## Restores what [method to_dict] produced.
func from_dict(data: Dictionary) -> void:
	reseed(str(data.get("master_seed", "0")).to_int())
	var states: Dictionary = data.get("streams", {})
	for system: String in states:
		stream(StringName(system)).state = str(states[system]).to_int()


## The seed for one stream. A hash keeps streams with similar names unrelated.
static func derive_seed(base: int, system: StringName) -> int:
	var digest := ("%d/%s" % [base, system]).sha256_text()
	# 15 hex digits is 60 bits, which always fits in a positive int.
	return digest.substr(0, 15).hex_to_int()
