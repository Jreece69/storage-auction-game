extends GutTest
## Weighted picks follow the weights and depend only on the seed.


func test_never_picks_a_zero_weight() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 500:
		var picked: StringName = Weighted.pick({&"yes": 1.0, &"no": 0.0}, rng)
		assert_eq(picked, &"yes")


func test_no_positive_weight_picks_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	assert_true(Weighted.pick({&"a": 0.0, &"b": 0.0}, rng) == null)
	assert_true(Weighted.pick({}, rng) == null)


func test_picks_follow_the_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var commons := 0
	for i in 4000:
		var key: StringName = Weighted.pick({&"common": 3.0, &"rare": 1.0}, rng)
		if key == &"common":
			commons += 1
	var share := commons / 4000.0
	assert_almost_eq(share, 0.75, 0.03, "a 3:1 weighting lands near 75%")


func test_insertion_order_does_not_change_picks() -> void:
	var first := _picks({&"apple": 2.0, &"banana": 1.0, &"cherry": 3.0})
	var second := _picks({&"cherry": 3.0, &"apple": 2.0, &"banana": 1.0})
	assert_eq(first, second)


func _picks(weights: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var picks := []
	for i in 20:
		picks.append(Weighted.pick(weights, rng))
	return picks
