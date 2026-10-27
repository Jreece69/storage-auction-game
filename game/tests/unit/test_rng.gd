extends GutTest
## The replay promise: one seed always produces the same game.

const SEED: int = 12345


func before_each() -> void:
	Rng.reseed(SEED)


func test_same_seed_replays_the_same_rolls() -> void:
	var first := _rolls(&"loot", 5)
	Rng.reseed(SEED)
	assert_eq(_rolls(&"loot", 5), first)


func test_streams_do_not_disturb_each_other() -> void:
	var auction_alone := _rolls(&"auction", 3)
	Rng.reseed(SEED)
	_rolls(&"loot", 10)
	assert_eq(_rolls(&"auction", 3), auction_alone, "drawing loot must not shift auction rolls")


func test_each_system_gets_its_own_sequence() -> void:
	assert_ne(_rolls(&"auction", 3), _rolls(&"loot", 3))


func test_state_survives_a_json_round_trip() -> void:
	# 2^53 + 1 cannot be stored exactly as a JSON number, so this fails if
	# seeds or states are ever written as plain numbers again.
	Rng.reseed(9_007_199_254_740_993)
	_rolls(&"loot", 7)
	var saved := JSON.stringify(Rng.to_dict())
	var expected := _rolls(&"loot", 3)

	var restored: Dictionary = JSON.parse_string(saved)
	Rng.from_dict(restored)

	assert_eq(Rng.master_seed, 9_007_199_254_740_993)
	assert_eq(_rolls(&"loot", 3), expected)


func _rolls(system: StringName, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(Rng.stream(system).randi())
	return out
