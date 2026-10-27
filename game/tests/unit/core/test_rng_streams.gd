extends GutTest
## Separate RngStreams instances (the balance sim, tests) never disturb the
## game's own Rng.


func test_same_seed_gives_the_same_rolls() -> void:
	var a := RngStreams.new(123)
	var b := RngStreams.new(123)
	assert_eq(a.stream(&"loot").randi(), b.stream(&"loot").randi())


func test_a_private_instance_leaves_the_game_rng_alone() -> void:
	Rng.reseed(5)
	var expected := Rng.stream(&"loot").randi()
	Rng.reseed(5)
	var private := RngStreams.new(5)
	for i in 10:
		private.stream(&"loot").randi()
	assert_eq(Rng.stream(&"loot").randi(), expected)


func test_round_trip_through_a_dictionary() -> void:
	var streams := RngStreams.new(77)
	streams.stream(&"auction").randi()
	var saved := streams.to_dict()
	var expected := streams.stream(&"auction").randi()
	var restored := RngStreams.new()
	restored.from_dict(saved)
	assert_eq(restored.stream(&"auction").randi(), expected)
