extends GutTest
## The end of the day: the numbers, then on to tomorrow or back to the title.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const SUMMARY_SCENE: PackedScene = preload("res://scenes/ui/day_summary.tscn")


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	GameState.new_game(41)
	watch_signals(EventBus)


func after_each() -> void:
	GameState.end_run()


func test_shows_the_days_numbers() -> void:
	var summary := _end_days(1)
	var screen := _open()
	assert_eq(_label(screen, "%TitleLabel").text, tr("SUMMARY_TITLE") % 1)
	assert_eq(_label(screen, "%ProfitLabel").text, tr("SUMMARY_PROFIT") % Money.format(JsonValue.as_int(summary["profit"])))
	assert_eq(_label(screen, "%TotalsLabel").text, tr("SUMMARY_TOTALS") % [Money.format(GameState.cash), Money.format(GameState.controller.net_worth())])
	var next_day: Button = screen.get_node("%NextDayButton")
	assert_eq(next_day.text, tr("SUMMARY_NEXT_DAY") % 2)
	assert_true(next_day.has_focus())


func test_rent_shows_on_the_night_it_is_paid() -> void:
	_end_days(Content.catalog.economy.rent_every_days)
	var rows: VBoxContainer = _open().get_node("%Rows")
	var lines: Array[String] = []
	for row in rows.get_children():
		lines.append((row as Label).text)
	assert_has(lines, tr("SUMMARY_RENT") % Money.format(Content.catalog.economy.rent_amount))


func test_next_day_goes_to_the_map() -> void:
	_end_days(1)
	var next_day: Button = _open().get_node("%NextDayButton")
	next_day.pressed.emit()
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.MAP])


func test_save_and_quit_keeps_tomorrow() -> void:
	_end_days(1)
	var save_quit: Button = _open().get_node("%SaveQuitButton")
	save_quit.pressed.emit()
	assert_false(GameState.has_run())
	assert_eq(SaveManager.load_game(SaveManager.AUTOSAVE), OK)
	assert_eq(GameState.day, 2)
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.TITLE])


## Plays [param days] empty days. Returns the last one's summary.
func _end_days(days: int) -> Dictionary:
	var summary: Dictionary = {}
	for i in days:
		GameState.controller.start_day()
		summary = GameState.controller.end_day()
	return summary


func _open() -> Control:
	var screen: Control = SUMMARY_SCENE.instantiate()
	add_child_autofree(screen)
	return screen


func _label(screen: Control, path: String) -> Label:
	return screen.get_node(path) as Label
