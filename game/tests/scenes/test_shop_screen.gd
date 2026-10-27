extends GutTest
## The shop: finds go from the back room onto the shelves with a price tag,
## customers come to this player's counter one at a time, and closing up ends
## the day and saves. In a crew, closing up waits for everyone.

const SaveSandbox := preload("res://tests/helpers/save_sandbox.gd")
const SHOP_SCENE: PackedScene = preload("res://scenes/shop/shop_screen.tscn")

var shop: ShopScreen
var controller: RunController
var flow: DayFlow


func before_all() -> void:
	SaveSandbox.enter()


func after_all() -> void:
	SaveSandbox.leave()


func before_each() -> void:
	SaveManager.delete_slot(SaveManager.AUTOSAVE)
	GameState.new_game(31)
	controller = GameState.controller
	flow = GameState.flow
	watch_signals(EventBus)


func after_each() -> void:
	GameState.end_run()


func test_the_back_room_lists_what_the_player_owns() -> void:
	var lamp := _give(&"brass_floor_lamp", 50)
	var doll := _give(&"porcelain_doll", 40)
	_open()
	assert_not_null(_named("Shelve_%d" % lamp))
	assert_not_null(_named("Shelve_%d" % doll))
	assert_true(_named("Shelve_%d" % lamp).has_focus(), "focus starts on the first item")


func test_an_empty_back_room_focuses_the_doors() -> void:
	_open()
	assert_true(_button("%OpenDoorsButton").has_focus())


func test_shelving_puts_the_item_out_at_the_suggested_price() -> void:
	var lamp := _give(&"brass_floor_lamp", 50)
	_open()
	_press_named("Shelve_%d" % lamp)
	var shop_floor := controller.run.shop
	assert_true(shop_floor.is_shelved(lamp))
	assert_eq(shop_floor.shelf_of[lamp], 0)
	assert_eq(shop_floor.price_of[lamp], controller.pricing.suggested_price(controller.run.items[lamp]))
	assert_null(_named("Shelve_%d" % lamp), "gone from the back room")
	assert_not_null(_named("Up_%d" % lamp), "on a shelf")


func test_price_tags_move_in_steps_and_focus_stays_put() -> void:
	var lamp := _give(&"brass_floor_lamp", 50)
	_open()
	_press_named("Shelve_%d" % lamp)
	var start: int = controller.run.shop.price_of[lamp]
	var step := controller.catalog.economy.shop.price_step
	_press_named("Up_%d" % lamp)
	assert_eq(controller.run.shop.price_of[lamp], start + step)
	assert_true(_named("Up_%d" % lamp).has_focus(), "the list rebuilds, focus doesn't jump")
	_press_named("Down_%d" % lamp)
	_press_named("Down_%d" % lamp)
	assert_eq(controller.run.shop.price_of[lamp], start - step)


func test_taking_an_item_down_returns_it_to_the_back_room() -> void:
	var lamp := _give(&"brass_floor_lamp", 50)
	_open()
	_press_named("Shelve_%d" % lamp)
	_press_named("Down_shelf_%d" % lamp)
	assert_false(controller.run.shop.is_shelved(lamp))
	assert_not_null(_named("Shelve_%d" % lamp))


func test_full_shelves_say_so() -> void:
	var space := controller.run.shop.shelf_count * controller.run.shop.slots_per_shelf
	var marbles: Array[int] = []
	for i in space + 1:
		marbles.append(_give(&"bag_of_marbles", 10))
	_open()
	for i in space:
		assert_true(shop.shelve(marbles[i]))
	assert_false(shop.shelve(marbles[space]))
	assert_eq(_label("%HintLabel").text, tr("SHOP_NO_ROOM"))


func test_with_empty_shelves_nobody_buys() -> void:
	_open()
	_press("%OpenDoorsButton")
	assert_eq(shop.mode, ShopScreen.Mode.SELLING)
	assert_null(_counter().customer)
	assert_eq(_label("%HintLabel").text, tr("SHOP_NOTHING_TO_SELL"))
	assert_true(_button("%NextCustomerButton").disabled)
	assert_true(_button("%CloseUpButton").has_focus())


func test_taking_an_offer_sells_the_item() -> void:
	_stock_and_open()
	var buyer := _next_offering()
	var offer := buyer.offer
	var cash_before := GameState.cash
	assert_eq(_button("%AcceptButton").text, tr("SHOP_ACCEPT") % Money.format(offer))
	_press("%AcceptButton")
	assert_eq(GameState.cash, cash_before + offer)
	assert_false(controller.run.items.has(buyer.item_uid))
	assert_eq(_label("%OutcomeLabel").text, tr("SHOP_SOLD") % Money.format(offer))
	assert_eq(controller.today.ledger.member(Crew.HOST).sales, offer, "the sale is credited to the seller")


func test_the_counter_starts_between_the_offer_and_the_tag() -> void:
	_stock_and_open()
	var buyer := _next_offering()
	assert_between(shop.counter_amount, buyer.offer + 1, buyer.tag)
	assert_eq(_button("%CounterButton").text, tr("SHOP_COUNTER") % Money.format(shop.counter_amount))


func test_countering_at_the_tag_sells_raises_or_loses_them() -> void:
	_stock_and_open()
	var buyer := _next_offering()
	while not _button("%HigherButton").disabled:
		_press("%HigherButton")
	assert_eq(shop.counter_amount, buyer.tag)
	var cash_before := GameState.cash
	_press("%CounterButton")
	var counter := _counter()
	match counter.outcome:
		ShopCounter.Outcome.DEAL:
			assert_eq(GameState.cash, cash_before + buyer.tag)
			assert_eq(_label("%OutcomeLabel").text, tr("SHOP_DEAL") % Money.format(buyer.tag))
		ShopCounter.Outcome.RAISED:
			assert_eq(_label("%OutcomeLabel").text, tr("SHOP_RAISED") % Money.format(counter.customer.offer))
			assert_true(_button("%AcceptButton").is_visible_in_tree(), "the haggling goes on")
		_:
			assert_eq(_label("%OutcomeLabel").text, tr("SHOP_LOST_PATIENCE"))
			assert_true(controller.run.items.has(buyer.item_uid))


func test_turning_a_customer_down_keeps_the_item() -> void:
	_stock_and_open()
	var buyer := _next_offering()
	_press("%DeclineButton")
	assert_true(controller.run.items.has(buyer.item_uid))
	assert_eq(_label("%OutcomeLabel").text, tr("SHOP_DECLINED"))


func test_after_the_last_customer_it_points_at_closing_up() -> void:
	_stock_and_open()
	for i in controller.today.customers_left + 1:
		if _counter().is_busy():
			_press("%DeclineButton")
		if _button("%NextCustomerButton").disabled:
			break
		_press("%NextCustomerButton")
	assert_eq(controller.today.customers_left, 0)
	assert_eq(_label("%HintLabel").text, tr("SHOP_NO_CUSTOMERS_LEFT"))
	assert_true(_button("%CloseUpButton").has_focus())


func test_restocking_between_customers() -> void:
	_stock_and_open()
	_next_offering()
	_press("%DeclineButton")
	_press("%RestockButton")
	assert_eq(shop.mode, ShopScreen.Mode.STOCKING)
	assert_true(_button("%OpenDoorsButton").is_visible_in_tree())


func test_an_item_a_crewmates_customer_holds_cant_be_taken_down() -> void:
	controller.crew = Crew.of_size(2)
	var stock: Array[int] = [_give(&"chrome_boombox", 60), _give(&"porcelain_doll", 40)]
	_open()
	for uid in stock:
		assert_true(shop.shelve(uid))
	for i in controller.today.customers_left:
		if flow.counter_of(&"p2").is_busy():
			break
		flow.handle(&"p2", "next_customer")
	var held := flow.counter_of(&"p2").customer.item_uid
	assert_true(_named("Down_shelf_%d" % held).disabled, "p2's customer has it in hand")


func test_closing_up_ends_the_day_and_saves() -> void:
	_open()
	_press("%CloseUpButton")
	assert_eq(GameState.day, 2)
	assert_eq(flow.stage, DayFlow.Stage.SUMMARY)
	assert_true(SaveManager.has_slot(SaveManager.AUTOSAVE))


func test_in_a_crew_closing_up_waits_for_everyone() -> void:
	controller.crew = Crew.of_size(2)
	_open()
	_press("%CloseUpButton")
	assert_eq(flow.stage, DayFlow.Stage.SHOP)
	assert_eq(_button("%CloseUpButton").text, tr("UI_WAITING_FOR_CREW") % [1, 2])
	flow.handle(&"p2", "close_up")
	assert_eq(flow.stage, DayFlow.Stage.SUMMARY)


## Skips the morning and opens the shop screen.
func _open() -> void:
	if flow.stage == DayFlow.Stage.MAP:
		assert_true(flow.handle(Crew.HOST, "skip_to_shop"))
	shop = SHOP_SCENE.instantiate()
	add_child_autofree(shop)


## Gives the player an item in good condition, in the back room. Returns its uid.
func _give(def_id: StringName, base_value: int) -> int:
	var uid := controller.run.uids.next()
	controller.run.items[uid] = ItemInstance.new(uid, def_id, base_value, &"good", false)
	return uid


## Shelves a few items and goes to the counter.
func _stock_and_open() -> void:
	var stock: Array[int] = [_give(&"chrome_boombox", 60), _give(&"retro_game_console", 150), _give(&"porcelain_doll", 40), _give(&"cordless_drill_kit", 60)]
	_open()
	for uid in stock:
		assert_true(shop.shelve(uid))
	_press("%OpenDoorsButton")


## Moves on until a customer at this counter is making an offer.
func _next_offering() -> Customer:
	for i in controller.today.customers_left + 1:
		if _counter().is_busy():
			return _counter().customer
		_press("%NextCustomerButton")
	fail_test("no customer made an offer")
	return null


func _counter() -> ShopCounter:
	return flow.counter_of(Crew.HOST)


func _press(path: String) -> void:
	var button := _button(path)
	assert_true(button.is_visible_in_tree(), "%s is showing" % path)
	assert_false(button.disabled, "%s is enabled" % path)
	button.pressed.emit()


func _press_named(node_name: String) -> void:
	var button := _named(node_name)
	assert_not_null(button, "%s exists" % node_name)
	assert_false(button.disabled)
	button.pressed.emit()


func _named(node_name: String) -> Button:
	return shop.find_child(node_name, true, false) as Button


func _button(path: String) -> Button:
	return shop.get_node(path) as Button


func _label(path: String) -> Label:
	return shop.get_node(path) as Label
