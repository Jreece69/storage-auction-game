extends GutTest
## GameState starts runs on the real content and passes the run's news on
## through EventBus.


func before_each() -> void:
	watch_signals(EventBus)


func after_each() -> void:
	GameState.end_run()


func test_new_game_starts_on_day_one_with_the_starting_cash() -> void:
	GameState.new_game(1)
	assert_true(GameState.has_run())
	assert_eq(GameState.day, 1)
	assert_eq(GameState.cash, Content.catalog.economy.starting_cash)


func test_new_game_reseeds_randomness() -> void:
	GameState.new_game(99)
	assert_eq(Rng.master_seed, 99)


func test_new_game_announces_the_cash() -> void:
	GameState.new_game(1)
	assert_signal_emitted_with_parameters(EventBus, "cash_changed", [Content.catalog.economy.starting_cash])


func test_the_run_reports_through_event_bus() -> void:
	GameState.new_game(1)
	GameState.controller.start_day()
	assert_signal_emitted_with_parameters(EventBus, "day_started", [1])
	GameState.controller.end_day()
	assert_signal_emitted(EventBus, "day_ended")


func test_ending_the_run() -> void:
	GameState.new_game(1)
	GameState.end_run()
	assert_false(GameState.has_run())
	assert_eq(GameState.cash, 0)
