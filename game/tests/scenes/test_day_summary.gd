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


func test_a_solo_day_has_no_crew_awards() -> void:
	_end_days(1)
	var awards: VBoxContainer = _open().get_node("%Awards")
	assert_eq(awards.get_child_count(), 0)


func test_a_crew_gets_awards() -> void:
	var flow := GameState.flow
	GameState.controller.crew = Crew.of_size(2)
	flow.handle(Crew.HOST, "skip_to_shop")
	GameState.controller.today.ledger.member(&"p2").sales = 30
	flow.handle(&"p1", "close_up")
	flow.handle(&"p2", "close_up")
	var awards: VBoxContainer = _open().get_node("%Awards")
	var lines: Array[String] = []
	for line in awards.get_children():
		lines.append((line as Label).text)
	assert_eq(lines, [tr("SUMMARY_AWARDS"), tr("AWARD_SILVER_TONGUE") % [tr("UI_PLAYER") % 2, "$30"]] as Array[String])


func test_next_day_goes_to_the_map() -> void:
	_end_days(1)
	var next_day: Button = _open().get_node("%NextDayButton")
	next_day.pressed.emit()
	assert_eq(GameState.flow.stage, DayFlow.Stage.MAP)
	assert_eq(GameState.controller.today.day, 2)


func test_save_and_quit_keeps_tomorrow() -> void:
	_end_days(1)
	var save_quit: Button = _open().get_node("%SaveQuitButton")
	save_quit.pressed.emit()
	assert_false(GameState.has_run())
	assert_eq(SaveManager.load_game(SaveManager.AUTOSAVE), OK)
	assert_eq(GameState.day, 2)
	assert_signal_emitted_with_parameters(EventBus, "screen_requested", [Screens.TITLE])


## Plays [param days] empty days through the day flow, ending on the last
## one's summary. Returns that summary.
func _end_days(days: int) -> Dictionary:
	var flow := GameState.flow
	for i in days:
		if flow.stage == DayFlow.Stage.SUMMARY:
			assert_true(flow.handle(Crew.HOST, "next_day"))
		assert_true(flow.handle(Crew.HOST, "skip_to_shop"))
		assert_true(flow.handle(Crew.HOST, "close_up"))
	assert_eq(flow.stage, DayFlow.Stage.SUMMARY)
	return GameState.controller.last_summary


func _open() -> Control:
	var screen: Control = SUMMARY_SCENE.instantiate()
	add_child_autofree(screen)
	return screen


func _label(screen: Control, path: String) -> Label:
	return screen.get_node(path) as Label
