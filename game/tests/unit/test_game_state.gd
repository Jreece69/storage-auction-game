extends GutTest
## Starting a game sets the run up and tells the rest of the game via EventBus.


func before_each() -> void:
	watch_signals(EventBus)


func test_new_game_starts_on_day_one_with_the_given_cash() -> void:
	GameState.new_game(1, 750)
	assert_eq(GameState.day, 1)
	assert_eq(GameState.cash, 750)


func test_new_game_announces_the_day_and_the_cash() -> void:
	GameState.new_game(1, 750)
	assert_signal_emitted_with_parameters(EventBus, "day_started", [1])
	assert_signal_emitted_with_parameters(EventBus, "cash_changed", [750])


func test_new_game_reseeds_randomness() -> void:
	GameState.new_game(99, 0)
	assert_eq(Rng.master_seed, 99)
