class_name ShopScreen
extends Control
## The afternoon in the shop: move finds from the back room onto the shelves
## and set their price tags, then serve customers at your counter. It draws
## the shop as DayFlow has it and sends this player's moves through
## GameState.act. In co-op the shelves are shared and every player has their
## own counter, so one can restock while another haggles.

enum Mode { STOCKING, SELLING }

## Whether this player is looking at the stock or at their counter. Each
## player's own choice, not part of the day.
var mode: Mode = Mode.STOCKING
## What this player will counter with.
var counter_amount: int = 0

var _flow: DayFlow
var _member: StringName
## The name of the list button to give focus back to after a rebuild.
var _focus_name: String = ""
## The customer the counter amount was worked out for.
var _countered_for: Dictionary = {}

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
	_flow = GameState.flow
	_member = GameState.local_member
	EventBus.cash_changed.connect(_show_cash)
	EventBus.flow_changed.connect(_redraw)
	_lower_button.pressed.connect(_nudge_counter.bind(-1))
	_higher_button.pressed.connect(_nudge_counter.bind(1))
	_counter_button.pressed.connect(_on_counter_pressed)
	_accept_button.pressed.connect(GameState.act.bind("accept"))
	_decline_button.pressed.connect(GameState.act.bind("decline"))
	_next_customer_button.pressed.connect(next_customer)
	_restock_button.pressed.connect(show_stocking)
	_open_doors_button.pressed.connect(open_doors)
	_close_up_button.pressed.connect(close_up)
	_title_label.text = tr("SHOP_TITLE") % _run().day
	show_stocking()


# --- Stocking --------------------------------------------------------------

## Back to moving stock and setting prices.
func show_stocking() -> void:
	mode = Mode.STOCKING
	_hint_label.text = ""
	_redraw()
	UiKit.focus(null, _back_room_items)
	if get_viewport().gui_get_focus_owner() == null:
		UiKit.focus(_open_doors_button, _shelf_list)


## Puts back-room item [param uid] on the first shelf with room for it.
func shelve(uid: int) -> bool:
	if GameState.act("shelve", {"uid": uid}):
		_hint_label.text = ""
		return true
	_hint_label.text = tr("SHOP_NO_ROOM")
	return false


func _unshelve(uid: int) -> void:
	GameState.act("unshelve", {"uid": uid})


func _reprice(uid: int, steps: int) -> void:
	_focus_name = ("Up_%d" if steps > 0 else "Down_%d") % uid
	if not GameState.act("reprice", {"uid": uid, "steps": steps}):
		_focus_name = ""


func _rebuild_stock() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if _focus_name.is_empty() and focused != null and (_back_room_items.is_ancestor_of(focused) or _shelf_list.is_ancestor_of(focused)):
		_focus_name = focused.name
	UiKit.clear(_back_room_items)
	UiKit.clear(_shelf_list)
	var run := _run()
	var pricing := _flow.controller.pricing
	var held := _flow.held_items()
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
			var take_down := _row_button(tr("SHOP_TAKE_DOWN"), _unshelve.bind(uid), "Down_shelf_%d" % uid)
			# A customer has it in hand.
			take_down.disabled = held.has(uid)
			row.add_child(take_down)
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

## Goes to this player's counter and calls the first customer over.
func open_doors() -> void:
	mode = Mode.SELLING
	_hint_label.text = ""
	if not _counter().is_busy():
		next_customer()
	else:
		_redraw()


## Calls the next customer over to this player's counter, if there is one.
func next_customer() -> void:
	if not GameState.act("next_customer"):
		_redraw()


func _nudge_counter(steps: int) -> void:
	var customer := _counter().customer
	counter_amount = clampi(counter_amount + steps * _step(), customer.offer + _step(), customer.tag)
	_draw_counter_amount()


func _on_counter_pressed() -> void:
	GameState.act("counter", {"amount": counter_amount})


func _draw_counter() -> void:
	var counter := _counter()
	var customer := counter.customer
	if customer == null:
		_customer_label.text = ""
		UiKit.show_text(_offer_label, "")
		UiKit.show_text(_patience_label, "")
		_show_outcome("")
		return
	var item_name := UiKit.item_name(counter.item_def)
	_customer_label.text = tr("SHOP_CUSTOMER") % [tr(customer.def.name_key), item_name, Money.format(customer.tag)]
	if customer.is_offering():
		UiKit.show_text(_offer_label, tr("SHOP_OFFER") % Money.format(customer.offer))
		UiKit.show_text(_patience_label, tr("SHOP_PATIENCE_LAST") if customer.patience_left <= 0 else tr("SHOP_PATIENCE") % customer.patience_left)
		UiKit.show_text(_outcome_label, tr("SHOP_RAISED") % Money.format(counter.amount) if counter.outcome == ShopCounter.Outcome.RAISED else "")
		_accept_button.text = tr("SHOP_ACCEPT") % Money.format(customer.offer)
		var lowest := customer.offer + _step()
		_counter_row.visible = lowest <= customer.tag
		# A fresh offer gets a fresh suggestion: halfway to the tag.
		var asked := {"item": customer.item_uid, "offer": customer.offer}
		if asked != _countered_for:
			_countered_for = asked
			counter_amount = clampi(_snap(roundi((customer.offer + customer.tag) / 2.0)), lowest, customer.tag)
		_draw_counter_amount()
		_deal_row.visible = true
		_after_row.visible = false
		if not (_accept_button.has_focus() or _counter_button.has_focus() or _lower_button.has_focus() or _higher_button.has_focus() or _decline_button.has_focus()):
			_accept_button.grab_focus()
	else:
		UiKit.show_text(_offer_label, "")
		UiKit.show_text(_patience_label, "")
		_show_outcome(_outcome_text(counter))


func _draw_counter_amount() -> void:
	var customer := _counter().customer
	_counter_button.text = tr("SHOP_COUNTER") % Money.format(counter_amount)
	_lower_button.text = UiKit.fmt("SHOP_CHEAPER", [Money.format(_step())])
	_higher_button.text = UiKit.fmt("SHOP_DEARER", [Money.format(_step())])
	_lower_button.disabled = counter_amount - _step() < customer.offer + _step()
	_higher_button.disabled = counter_amount + _step() > customer.tag


## The customer is done, one way or another: show how it went and what's next.
func _show_outcome(outcome: String) -> void:
	UiKit.show_text(_outcome_label, outcome)
	_counter_row.visible = false
	_deal_row.visible = false
	_after_row.visible = true
	if _flow.more_customers():
		_next_customer_button.disabled = false
		_hint_label.text = ""
		if not (_next_customer_button.has_focus() or _restock_button.has_focus()):
			_next_customer_button.grab_focus()
	else:
		# Nobody else is coming: say so and point at closing up.
		_next_customer_button.disabled = true
		_hint_label.text = tr("SHOP_NOTHING_TO_SELL") if _run().shop.shelved_uids().is_empty() else tr("SHOP_NO_CUSTOMERS_LEFT")
		if not _close_up_button.disabled:
			_close_up_button.grab_focus()


func _outcome_text(counter: ShopCounter) -> String:
	match counter.outcome:
		ShopCounter.Outcome.SOLD:
			return tr("SHOP_SOLD") % Money.format(counter.amount)
		ShopCounter.Outcome.DEAL:
			return tr("SHOP_DEAL") % Money.format(counter.amount)
		ShopCounter.Outcome.LOST_PATIENCE:
			return tr("SHOP_LOST_PATIENCE")
		ShopCounter.Outcome.DECLINED:
			return tr("SHOP_DECLINED")
		ShopCounter.Outcome.BROWSING:
			return tr("SHOP_BROWSING")
		ShopCounter.Outcome.TOO_PRICEY:
			return tr("SHOP_TOO_PRICEY")
		_:
			return ""


# --- Closing ---------------------------------------------------------------

## Ends the day once the whole crew has closed up (see DayFlow).
func close_up() -> void:
	GameState.act("close_up")


# --- Drawing ----------------------------------------------------------------

## Brings the screen up to date with the shop.
func _redraw() -> void:
	if _flow.stage != DayFlow.Stage.SHOP:
		return
	_show_cash(GameState.cash)
	_stock_panel.visible = mode == Mode.STOCKING
	_customer_panel.visible = mode == Mode.SELLING
	_open_doors_button.visible = mode == Mode.STOCKING
	if mode == Mode.STOCKING:
		_rebuild_stock()
	else:
		_draw_counter()
	var crew_size := _flow.crew().size()
	var closed := _flow.ready.has(_member)
	_close_up_button.disabled = closed
	if crew_size <= 1:
		_close_up_button.text = tr("SHOP_CLOSE_UP")
	elif closed:
		_close_up_button.text = tr("UI_WAITING_FOR_CREW") % [_flow.ready.size(), crew_size]
	else:
		_close_up_button.text = tr("UI_CREW_READY") % [tr("SHOP_CLOSE_UP"), _flow.ready.size(), crew_size]
	_customers_left_label.text = tr("SHOP_CUSTOMERS_LEFT") % _flow.controller.today.customers_left


func _counter() -> ShopCounter:
	return _flow.counter_of(_member)


func _run() -> RunState:
	return _flow.controller.run


func _show_cash(cash: int) -> void:
	_cash_label.text = tr("UI_CASH") % Money.format(cash)


func _step() -> int:
	return _flow.controller.catalog.economy.shop.price_step


## [param amount] rounded to the nearest price step.
func _snap(amount: int) -> int:
	return roundi(amount / float(_step())) * _step()
