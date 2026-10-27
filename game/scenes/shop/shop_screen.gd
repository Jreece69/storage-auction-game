class_name ShopScreen
extends Control
## The afternoon in the shop: move finds from the back room onto the
## shelves and set their price tags, then open the doors and haggle with
## each customer. Closing up ends the day and saves.

enum Mode { STOCKING, SELLING }

## Stocking the shelves or serving customers. Read by tests.
var mode: Mode = Mode.STOCKING
## The shopper at the counter, or null.
var customer: Customer = null
## What the player will counter with.
var counter_amount: int = 0

var _controller: RunController
var _member: StringName
## The name of the list button to give focus back to after a rebuild.
var _focus_name: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _cash_label: Label = %CashLabel
@onready var _stock_panel: Control = %StockPanel
@onready var _back_room_items: VBoxContainer = %BackRoomItems
@onready var _shelf_list: VBoxContainer = %ShelfList
@onready var _customer_panel: Control = %CustomerPanel
@onready var _customer_label: Label = %CustomerLabel
@onready var _offer_label: Label = %OfferLabel
@onready var _patience_label: Label = %PatienceLabel
@onready var _counter_row: Control = %CounterRow
@onready var _lower_button: Button = %LowerButton
@onready var _counter_button: Button = %CounterButton
@onready var _higher_button: Button = %HigherButton
@onready var _deal_row: Control = %DealRow
@onready var _accept_button: Button = %AcceptButton
@onready var _decline_button: Button = %DeclineButton
@onready var _outcome_label: Label = %OutcomeLabel
@onready var _after_row: Control = %AfterRow
@onready var _next_customer_button: Button = %NextCustomerButton
@onready var _restock_button: Button = %RestockButton
@onready var _hint_label: Label = %HintLabel
@onready var _open_doors_button: Button = %OpenDoorsButton
@onready var _close_up_button: Button = %CloseUpButton
@onready var _customers_left_label: Label = %CustomersLeftLabel


func _ready() -> void:
	_controller = GameState.controller
	_member = GameState.local_member
	if _controller.start_day().phase == DayPlan.Phase.MORNING:
		_controller.start_afternoon()
	EventBus.cash_changed.connect(_show_cash)
	_lower_button.pressed.connect(_nudge_counter.bind(-1))
	_higher_button.pressed.connect(_nudge_counter.bind(1))
	_counter_button.pressed.connect(_on_counter_pressed)
	_accept_button.pressed.connect(_on_accept_pressed)
	_decline_button.pressed.connect(_on_decline_pressed)
	_next_customer_button.pressed.connect(next_customer)
	_restock_button.pressed.connect(show_stocking)
	_open_doors_button.pressed.connect(open_doors)
	_close_up_button.pressed.connect(close_up)
	_title_label.text = tr("SHOP_TITLE") % _controller.run.day
	_show_cash(_controller.run.cash)
	show_stocking()


# --- Stocking --------------------------------------------------------------

## Back to moving stock and setting prices.
func show_stocking() -> void:
	mode = Mode.STOCKING
	customer = null
	_stock_panel.visible = true
	_customer_panel.visible = false
	_open_doors_button.visible = true
	_hint_label.text = ""
	_rebuild_stock()
	_refresh_footer()
	UiKit.focus(null, _back_room_items)
	if get_viewport().gui_get_focus_owner() == null:
		UiKit.focus(_open_doors_button, _shelf_list)


## Puts back-room item [param uid] on the first shelf with room for it.
func shelve(uid: int) -> bool:
	for shelf in _controller.run.shop.shelf_count:
		if _controller.shelve(uid, shelf):
			_hint_label.text = ""
			_rebuild_stock()
			return true
	_hint_label.text = tr("SHOP_NO_ROOM")
	return false


func _unshelve(uid: int) -> void:
	_controller.unshelve(uid)
	_rebuild_stock()


func _reprice(uid: int, steps: int) -> void:
	var step := _step()
	var price: int = _controller.run.shop.price_of[uid]
	_controller.set_price(uid, maxi(step, price + steps * step))
	_focus_name = ("Up_%d" if steps > 0 else "Down_%d") % uid
	_rebuild_stock()


func _rebuild_stock() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if _focus_name.is_empty() and focused != null and (_back_room_items.is_ancestor_of(focused) or _shelf_list.is_ancestor_of(focused)):
		_focus_name = focused.name
	UiKit.clear(_back_room_items)
	UiKit.clear(_shelf_list)
	var run := _controller.run
	var pricing := _controller.pricing
	var back_room := run.backroom_uids()
	if back_room.is_empty():
		_back_room_items.add_child(UiKit.label(tr("SHOP_EMPTY_BACK_ROOM"), UiKit.SMALL))
	for uid in back_room:
		var item := run.items[uid]
		var def := pricing.def_of(item)
		var row := HBoxContainer.new()
		var info := UiKit.label(UiKit.fmt("SHOP_BACK_ROOM_ITEM", [UiKit.item_name(item.def_id), UiKit.state_of(item), Money.format(pricing.market_value(item)), def.size]), UiKit.SMALL)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_color_override("font_color", UiKit.rarity_color(def.rarity))
		row.add_child(info)
		row.add_child(_row_button(tr("SHOP_PUT_ON_SHELF"), shelve.bind(uid), "Shelve_%d" % uid))
		_back_room_items.add_child(row)
	var shop := run.shop
	for shelf in shop.shelf_count:
		_shelf_list.add_child(UiKit.label(UiKit.fmt("SHOP_SHELF", [shelf + 1, shop.free_space(shelf), shop.slots_per_shelf]), UiKit.SMALL))
		for uid in shop.items_on(shelf):
			var item := run.items[uid]
			var row := HBoxContainer.new()
			var info := UiKit.label(UiKit.fmt("SHOP_TAGGED", [UiKit.item_name(item.def_id), Money.format(shop.price_of[uid]), Money.format(pricing.market_value(item))]), UiKit.SMALL)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			row.add_child(_row_button(UiKit.fmt("SHOP_CHEAPER", [Money.format(_step())]), _reprice.bind(uid, -1), "Down_%d" % uid))
			row.add_child(_row_button(UiKit.fmt("SHOP_DEARER", [Money.format(_step())]), _reprice.bind(uid, 1), "Up_%d" % uid))
			row.add_child(_row_button(tr("SHOP_TAKE_DOWN"), _unshelve.bind(uid), "Down_shelf_%d" % uid))
			_shelf_list.add_child(row)
	_restore_focus()


## A compact button for a row in the stock lists.
func _row_button(content: String, on_pressed: Callable, node_name: String) -> Button:
	var made := UiKit.button(content, on_pressed, node_name, UiKit.SMALL)
	made.custom_minimum_size = Vector2(64, 44)
	return made


## After a rebuild, puts focus back on the button the player was using, or
## on the nearest sensible one if it's gone (the item moved or sold).
func _restore_focus() -> void:
	var wanted := _focus_name
	_focus_name = ""
	if wanted.is_empty() or mode != Mode.STOCKING:
		return
	var again := find_child(wanted, true, false) as Control
	UiKit.focus(again, _back_room_items)
	if get_viewport().gui_get_focus_owner() == null:
		UiKit.focus(_open_doors_button, _shelf_list)


# --- Selling ---------------------------------------------------------------

## Starts serving customers, one at a time.
func open_doors() -> void:
	mode = Mode.SELLING
	_stock_panel.visible = false
	_customer_panel.visible = true
	_open_doors_button.visible = false
	_hint_label.text = ""
	next_customer()


## Brings the next shopper to the counter, if there is one.
func next_customer() -> void:
	customer = _controller.next_customer()
	_refresh_footer()
	if customer == null:
		_customer_label.text = ""
		UiKit.show_text(_offer_label, "")
		_show_outcome("")
		return
	var item := _controller.run.items[customer.item_uid]
	_customer_label.text = tr("SHOP_CUSTOMER") % [tr(customer.def.name_key), UiKit.item_name(item.def_id), Money.format(customer.tag)]
	if customer.is_offering():
		UiKit.show_text(_outcome_label, "")
		_show_offer()
	elif customer.reason == Customer.Reason.BROWSING:
		_show_outcome(tr("SHOP_BROWSING"))
	else:
		_show_outcome(tr("SHOP_TOO_PRICEY"))


func _show_offer() -> void:
	UiKit.show_text(_offer_label, tr("SHOP_OFFER") % Money.format(customer.offer))
	UiKit.show_text(_patience_label, tr("SHOP_PATIENCE_LAST") if customer.patience_left <= 0 else tr("SHOP_PATIENCE") % customer.patience_left)
	_accept_button.text = tr("SHOP_ACCEPT") % Money.format(customer.offer)
	var lowest := customer.offer + _step()
	_counter_row.visible = lowest <= customer.tag
	counter_amount = clampi(_snap(roundi((customer.offer + customer.tag) / 2.0)), lowest, customer.tag)
	_refresh_counter()
	_deal_row.visible = true
	_after_row.visible = false
	_accept_button.grab_focus()


## Moves the counter-offer up or down one price step.
func _nudge_counter(steps: int) -> void:
	counter_amount = clampi(counter_amount + steps * _step(), customer.offer + _step(), customer.tag)
	_refresh_counter()


func _refresh_counter() -> void:
	_counter_button.text = tr("SHOP_COUNTER") % Money.format(counter_amount)
	_lower_button.text = UiKit.fmt("SHOP_CHEAPER", [Money.format(_step())])
	_higher_button.text = UiKit.fmt("SHOP_DEARER", [Money.format(_step())])
	_lower_button.disabled = counter_amount - _step() < customer.offer + _step()
	_higher_button.disabled = counter_amount + _step() > customer.tag


func _on_accept_pressed() -> void:
	var price := customer.accept()
	_controller.complete_sale(customer, _member)
	_show_outcome(tr("SHOP_SOLD") % Money.format(price))


func _on_counter_pressed() -> void:
	match customer.counter(counter_amount):
		"accept":
			_controller.complete_sale(customer, _member)
			_show_outcome(tr("SHOP_DEAL") % Money.format(customer.offer))
		"raise":
			_show_offer()
			UiKit.show_text(_outcome_label, tr("SHOP_RAISED") % Money.format(customer.offer))
		_:
			_show_outcome(tr("SHOP_LOST_PATIENCE"))


func _on_decline_pressed() -> void:
	customer.decline()
	_show_outcome(tr("SHOP_DECLINED"))


## The customer is done, one way or another.
func _show_outcome(outcome: String) -> void:
	UiKit.show_text(_outcome_label, outcome)
	UiKit.show_text(_patience_label, "")
	_counter_row.visible = false
	_deal_row.visible = false
	_after_row.visible = true
	if customer != null and customer.state != Customer.State.OFFERING:
		UiKit.show_text(_offer_label, "")
	_refresh_footer()
	if _more_customers():
		_next_customer_button.disabled = false
		_next_customer_button.grab_focus()
	else:
		# Nobody else is coming: say so and point at closing up.
		_next_customer_button.disabled = true
		_hint_label.text = tr("SHOP_NOTHING_TO_SELL") if _controller.run.shop.shelved_uids().is_empty() else tr("SHOP_NO_CUSTOMERS_LEFT")
		_close_up_button.grab_focus()


func _more_customers() -> bool:
	var today := _controller.today
	return today.customers_left > 0 and not _controller.run.shop.shelved_uids().is_empty()


# --- Closing ---------------------------------------------------------------

## Ends the day, saves, and shows the summary.
func close_up() -> void:
	_controller.end_day()
	SaveManager.save_game(SaveManager.AUTOSAVE)
	Screens.go(Screens.SUMMARY)


func _refresh_footer() -> void:
	_customers_left_label.text = tr("SHOP_CUSTOMERS_LEFT") % _controller.today.customers_left


func _show_cash(cash: int) -> void:
	_cash_label.text = tr("UI_CASH") % Money.format(cash)


func _step() -> int:
	return _controller.catalog.economy.shop.price_step


## [param amount] rounded to the nearest price step.
func _snap(amount: int) -> int:
	return roundi(amount / float(_step())) * _step()
