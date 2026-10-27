class_name MapScreen
extends Control
## The start of each day: where things stand and where to go next. The
## vertical slice turns this into the map, with zones to drive to.

@onready var _day_label: Label = %DayLabel
@onready var _cash_label: Label = %CashLabel
@onready var _net_worth_label: Label = %NetWorthLabel
@onready var _rent_label: Label = %RentLabel
@onready var _auction_button: Button = %AuctionButton
@onready var _shop_button: Button = %ShopButton
@onready var _scrap_job_button: Button = %ScrapJobButton
@onready var _broke_hint_label: Label = %BrokeHintLabel
@onready var _save_quit_button: Button = %SaveQuitButton

var _controller: RunController


func _ready() -> void:
	_controller = GameState.controller
	var run := _controller.run
	var economy := _controller.catalog.economy
	_day_label.text = tr("MAP_DAY") % run.day
	_cash_label.text = tr("UI_CASH") % Money.format(run.cash)
	_net_worth_label.text = tr("UI_NET_WORTH") % Money.format(_controller.net_worth())
	var rent := Money.format(economy.rent_amount)
	var due_in := _controller.days_until_rent()
	if due_in == 0:
		_rent_label.text = tr("MAP_RENT_TONIGHT") % rent
	elif due_in == 1:
		_rent_label.text = tr("MAP_RENT_TOMORROW") % rent
	else:
		_rent_label.text = tr("MAP_RENT_IN") % [rent, due_in]
	var zone := _controller.zone()
	_auction_button.text = tr("MAP_GO_AUCTION") % [tr(zone.name_key), zone.lockers_per_day]
	_scrap_job_button.text = tr("MAP_SCRAP_JOB") % Money.format(economy.scrap_job_pay)
	var broke := _controller.can_take_scrap_job()
	_scrap_job_button.visible = broke
	_broke_hint_label.visible = broke

	_auction_button.pressed.connect(GameState.act.bind("go_to_auction"))
	_shop_button.pressed.connect(GameState.act.bind("skip_to_shop"))
	_scrap_job_button.pressed.connect(GameState.act.bind("scrap_job"))
	_save_quit_button.pressed.connect(_on_save_quit_pressed)
	if broke:
		_scrap_job_button.grab_focus()
	else:
		_auction_button.grab_focus()


func _on_save_quit_pressed() -> void:
	SaveManager.save_game(SaveManager.AUTOSAVE)
	GameState.end_run()
	Screens.go(Screens.TITLE)
