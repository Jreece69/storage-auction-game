class_name DaySummary
extends Control
## The end of the day: what was spent, sold and found, and today's profit.
## The game has already saved by now (end_day starts tomorrow's snapshot).

const PROFIT_COLOR: Color = Color(0.49, 0.82, 0.45)
const LOSS_COLOR: Color = Color(0.94, 0.42, 0.38)

@onready var _title_label: Label = %TitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _profit_label: Label = %ProfitLabel
@onready var _best_find_label: Label = %BestFindLabel
@onready var _totals_label: Label = %TotalsLabel
@onready var _awards: VBoxContainer = %Awards
@onready var _next_day_button: Button = %NextDayButton
@onready var _save_quit_button: Button = %SaveQuitButton


func _ready() -> void:
	var controller := GameState.controller
	var summary := controller.last_summary
	var day := JsonValue.as_int(summary.get("day", controller.run.day - 1))
	_title_label.text = tr("SUMMARY_TITLE") % day
	var won := JsonValue.as_int(summary.get("lockers_won", 0))
	var lots := won + JsonValue.as_int(summary.get("lockers_lost", 0))
	_add_row(tr("SUMMARY_LOCKERS") % [won, lots])
	_add_row(tr("SUMMARY_SPENT") % _money(summary, "spent_on_lockers"))
	_add_row(tr("SUMMARY_SALES") % [_money(summary, "sales"), JsonValue.as_int(summary.get("items_sold", 0))])
	_add_row(tr("SUMMARY_SCRAP") % _money(summary, "scrap"))
	if JsonValue.as_int(summary.get("scrap_job", 0)) > 0:
		_add_row(tr("SUMMARY_SCRAP_JOB") % _money(summary, "scrap_job"))
	if JsonValue.as_int(summary.get("rent", 0)) > 0:
		_add_row(tr("SUMMARY_RENT") % _money(summary, "rent"))
	var profit := JsonValue.as_int(summary.get("profit", 0))
	_profit_label.text = tr("SUMMARY_PROFIT") % Money.format(profit)
	if profit != 0:
		_profit_label.add_theme_color_override("font_color", PROFIT_COLOR if profit > 0 else LOSS_COLOR)
	var best_def := JsonValue.as_name(summary.get("best_find_def", ""))
	if best_def == &"":
		_best_find_label.text = tr("SUMMARY_NO_FIND")
	else:
		_best_find_label.text = tr("SUMMARY_BEST_FIND") % [UiKit.item_name(best_def), _money(summary, "best_find_value")]
	_totals_label.text = tr("SUMMARY_TOTALS") % [_money(summary, "end_cash"), _money(summary, "net_worth")]
	_add_awards(summary)
	_next_day_button.text = tr("SUMMARY_NEXT_DAY") % controller.run.day
	if Session.is_client():
		_save_quit_button.text = tr("MAP_LEAVE")
	_next_day_button.pressed.connect(_on_next_day_pressed)
	_save_quit_button.pressed.connect(_on_save_quit_pressed)
	_next_day_button.grab_focus()


func _on_next_day_pressed() -> void:
	GameState.act("next_day")


## Saves and quits; in co-op the host's quitting ends the game for everyone,
## and a friend just leaves.
func _on_save_quit_pressed() -> void:
	if Session.is_host():
		SaveManager.save_game(SaveManager.AUTOSAVE)
	Session.leave()
	GameState.end_run()
	Screens.go(Screens.TITLE)


## The crew awards, when there's a crew to hand them to.
func _add_awards(summary: Dictionary) -> void:
	var awards := CrewAwards.for_day(summary)
	if awards.is_empty():
		return
	var heading := UiKit.label(tr("SUMMARY_AWARDS"))
	heading.add_theme_color_override("font_color", Color(0.957, 0.725, 0.329))
	_awards.add_child(heading)
	for award in awards:
		var kind: StringName = award["award"]
		var who := UiKit.bidder_name(JsonValue.as_name(award["member"]))
		var amount := JsonValue.as_int(award["amount"])
		var shown := str(amount) if kind == &"friendly_fire" else Money.format(amount)
		_awards.add_child(UiKit.label(tr("AWARD_" + String(kind).to_upper()) % [who, shown]))


func _add_row(content: String) -> void:
	_rows.add_child(UiKit.label(content))


func _money(summary: Dictionary, key: String) -> String:
	return Money.format(JsonValue.as_int(summary.get(key, 0)))
