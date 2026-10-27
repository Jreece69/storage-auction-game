extends GutTest
## The day flow runs a day for a crew: the clocks, the stages, each member's
## moves, the steps that wait for everyone, and copies for other players that
## match the host's.

const Fixture := preload("res://tests/helpers/fixture.gd")
const MAX_TICKS: int = 5000

var catalog: Catalog
var controller: RunController
var flow: DayFlow


func before_each() -> void:
	catalog = Fixture.catalog()
	controller = RunController.new_run(catalog, RngStreams.new(7))
	flow = DayFlow.new(controller)


func test_the_day_starts_on_the_map() -> void:
	flow.start()
	assert_eq(flow.stage, DayFlow.Stage.MAP)
	assert_eq(controller.today.lockers.size(), 3)


func test_only_crew_members_can_move() -> void:
	flow.start()
	assert_false(flow.handle(&"p3", "go_to_auction"), "p3 isn't in a crew of one")
	assert_true(flow.handle(Crew.HOST, "go_to_auction"))


func test_moves_that_dont_fit_the_moment_change_nothing() -> void:
	flow.start()
	watch_signals(flow)
	assert_false(flow.handle(Crew.HOST, "raise"), "no auction on the map")
	assert_false(flow.handle(Crew.HOST, "close_up"))
	assert_signal_not_emitted(flow, "changed")


func test_the_peek_runs_out_into_the_bidding() -> void:
	_to_peek(1)
	assert_almost_eq(flow.peek_left, 20.0, 0.001)
	flow.tick(19.9)
	assert_eq(flow.stage, DayFlow.Stage.PEEK)
	flow.tick(0.2)
	assert_eq(flow.stage, DayFlow.Stage.BIDDING)
	assert_not_null(flow.auction)


func test_bidding_early_waits_for_the_whole_crew() -> void:
	_to_peek(2)
	assert_true(flow.handle(&"p1", "ready"))
	assert_eq(flow.stage, DayFlow.Stage.PEEK, "p2 is still looking")
	assert_false(flow.handle(&"p1", "ready"), "saying it twice changes nothing")
	flow.handle(&"p2", "ready")
	assert_eq(flow.stage, DayFlow.Stage.BIDDING)


func test_sitting_out_alone_hands_the_locker_to_the_rivals() -> void:
	_to_peek(1)
	flow.handle(Crew.HOST, "sit_out")
	assert_eq(flow.stage, DayFlow.Stage.RESULT)
	assert_true(controller.today.is_settled(controller.today.lockers[0]))
	assert_false(flow.crew_won())


func test_a_crewmate_who_sits_out_is_out_of_the_bidding() -> void:
	_to_peek(2)
	flow.handle(&"p1", "ready")
	flow.handle(&"p2", "sit_out")
	assert_eq(flow.stage, DayFlow.Stage.BIDDING)
	assert_has(flow.auction.crew_out, &"p2")
	assert_false(flow.handle(&"p2", "raise"), "they sat it out")


func test_crewmates_bid_against_each_other() -> void:
	controller.run.cash = 100000
	_to_bidding(2)
	watch_signals(flow)
	assert_true(flow.handle(&"p1", "raise"))
	assert_true(flow.handle(&"p2", "raise"))
	assert_eq(flow.auction.high_bidder, &"p2")
	assert_eq(flow.auction.friendly_fire[&"p2"], 1)
	assert_signal_emit_count(flow, "auction_events", 2)


func test_a_win_goes_through_the_reveal_and_the_van() -> void:
	controller.run.cash = 100000
	_to_bidding(1)
	_win(Crew.HOST)
	assert_eq(flow.stage, DayFlow.Stage.RESULT)
	assert_true(flow.crew_won())
	flow.handle(Crew.HOST, "continue")
	assert_eq(flow.stage, DayFlow.Stage.REVEAL)
	assert_false(flow.handle(Crew.HOST, "load"), "nothing to load until it's all out")
	flow.tick(DayFlow.REVEAL_INTERVAL + 0.01)
	assert_eq(flow.revealed, 1)
	flow.handle(Crew.HOST, "show_all")
	assert_eq(flow.revealed, flow.locker.items.size())
	flow.handle(Crew.HOST, "load")
	assert_eq(flow.stage, DayFlow.Stage.HAUL)
	var loaded := flow.haul.selected_uids()
	flow.handle(Crew.HOST, "drive")
	for uid in loaded:
		assert_true(controller.run.items.has(uid))
	assert_eq(flow.stage, DayFlow.Stage.PEEK)
	assert_eq(flow.locker.lot_number, 2)


func test_driving_home_waits_for_everyone() -> void:
	controller.run.cash = 100000
	_to_bidding(2)
	_win(&"p2")
	flow.handle(&"p1", "continue")
	flow.handle(&"p1", "show_all")
	flow.handle(&"p2", "load")
	flow.handle(&"p1", "drive")
	assert_eq(flow.stage, DayFlow.Stage.HAUL, "p2 is still packing")
	flow.handle(&"p2", "drive")
	assert_eq(flow.stage, DayFlow.Stage.PEEK)


func test_after_the_last_locker_the_shop_opens() -> void:
	_to_peek(1)
	for lot in 3:
		flow.handle(Crew.HOST, "sit_out")
		flow.handle(Crew.HOST, "continue")
	assert_eq(flow.stage, DayFlow.Stage.MORNING_DONE)
	flow.handle(Crew.HOST, "open_shop")
	assert_eq(flow.stage, DayFlow.Stage.SHOP)
	assert_eq(controller.today.customers_left, catalog.economy.shop.customers_per_day)


func test_a_bigger_crew_gets_more_customers() -> void:
	_to_shop(3)
	var shop_rules := catalog.economy.shop
	assert_eq(controller.today.customers_left, shop_rules.customers_per_day + 2 * shop_rules.crew_extra_customers)
	assert_eq(flow.counters.size(), 3, "a counter each")


func test_each_member_serves_their_own_customer() -> void:
	_to_shop(2)
	_stock([&"chair", &"doll", &"lamp"])
	assert_true(flow.handle(&"p1", "next_customer"))
	assert_true(flow.handle(&"p2", "next_customer"))
	var first := flow.counter_of(&"p1").customer
	var second := flow.counter_of(&"p2").customer
	assert_ne(first.item_uid, second.item_uid, "nobody picks up what someone else is holding")
	assert_false(flow.handle(&"p1", "next_customer"), "p1 is still serving")


func test_a_sale_is_credited_to_whoever_made_it() -> void:
	_to_shop(2)
	_stock([&"chair"])
	flow.handle(&"p2", "next_customer")
	var counter := flow.counter_of(&"p2")
	var offer := counter.customer.offer
	var cash := controller.run.cash
	assert_true(flow.handle(&"p2", "accept"))
	assert_eq(counter.outcome, ShopCounter.Outcome.SOLD)
	assert_eq(controller.run.cash, cash + offer)
	assert_eq(controller.today.ledger.member(&"p2").sales, offer)


func test_haggling_at_a_counter() -> void:
	_to_shop(1)
	_stock([&"lamp"])
	flow.handle(Crew.HOST, "next_customer")
	var counter := flow.counter_of(Crew.HOST)
	assert_false(flow.handle(Crew.HOST, "counter", {"amount": counter.customer.offer}), "a counter has to be higher")
	assert_true(flow.handle(Crew.HOST, "counter", {"amount": counter.customer.tag}))
	assert_has([ShopCounter.Outcome.DEAL, ShopCounter.Outcome.RAISED, ShopCounter.Outcome.LOST_PATIENCE], counter.outcome)


func test_an_item_in_a_customers_hands_stays_on_the_shelf() -> void:
	_to_shop(1)
	var uids := _stock([&"chair"])
	flow.handle(Crew.HOST, "next_customer")
	assert_false(flow.handle(Crew.HOST, "unshelve", {"uid": uids[0]}))
	flow.handle(Crew.HOST, "decline")
	assert_true(flow.handle(Crew.HOST, "unshelve", {"uid": uids[0]}))


func test_price_tags_move_in_steps_and_never_below_one_step() -> void:
	_to_shop(1)
	var uid := _stock([&"doll"])[0]
	var shop := controller.run.shop
	var start: int = shop.price_of[uid]
	assert_true(flow.handle(Crew.HOST, "reprice", {"uid": uid, "steps": 2}))
	assert_eq(shop.price_of[uid], start + 10)
	flow.handle(Crew.HOST, "reprice", {"uid": uid, "steps": -1000})
	assert_eq(shop.price_of[uid], 5)


func test_closing_up_waits_for_everyone_then_ends_the_day() -> void:
	_to_shop(2)
	watch_signals(flow)
	flow.handle(&"p1", "close_up")
	assert_eq(flow.stage, DayFlow.Stage.SHOP)
	flow.handle(&"p2", "close_up")
	assert_eq(flow.stage, DayFlow.Stage.SUMMARY)
	assert_eq(controller.run.day, 2)
	assert_signal_emitted(flow, "day_closed")
	flow.handle(&"p2", "next_day")
	assert_eq(flow.stage, DayFlow.Stage.MAP)
	assert_eq(controller.today.day, 2)


func test_a_player_who_drops_out_stops_holding_up_the_crew() -> void:
	_to_shop(2)
	flow.handle(&"p1", "close_up")
	flow.drop_member(&"p2")
	assert_eq(flow.stage, DayFlow.Stage.SUMMARY)
	assert_eq(controller.crew, [&"p1"] as Array[StringName])


func test_a_player_who_drops_out_mid_auction_passes() -> void:
	controller.run.cash = 100000
	_to_bidding(2)
	flow.drop_member(&"p2")
	assert_has(flow.auction.crew_out, &"p2")


func test_the_scrap_job_goes_straight_to_the_shop() -> void:
	controller.run.cash = 10
	flow.start()
	assert_true(flow.handle(Crew.HOST, "scrap_job"))
	assert_eq(flow.stage, DayFlow.Stage.SHOP)
	assert_eq(controller.run.cash, 10 + catalog.economy.scrap_job_pay)


func test_copies_match_the_host_all_through_the_day() -> void:
	controller.run.cash = 100000
	_to_peek(2)
	_assert_copy_matches("peek")
	flow.handle(&"p1", "ready")
	flow.handle(&"p2", "ready")
	flow.handle(&"p1", "raise")
	flow.tick(1.3)
	_assert_copy_matches("bidding")
	_win(&"p1")
	_assert_copy_matches("result")
	flow.handle(&"p1", "continue")
	flow.handle(&"p1", "show_all")
	flow.handle(&"p1", "load")
	_assert_copy_matches("haul")
	flow.handle(&"p1", "drive")
	flow.handle(&"p2", "drive")
	for lot in 2:
		flow.handle(&"p1", "sit_out")
		flow.handle(&"p2", "sit_out")
		flow.handle(&"p1", "continue")
	flow.handle(&"p1", "open_shop")
	for uid in controller.run.backroom_uids():
		flow.handle(&"p2", "shelve", {"uid": uid})
	flow.handle(&"p1", "next_customer")
	flow.handle(&"p2", "next_customer")
	_assert_copy_matches("shop")
	flow.handle(&"p1", "close_up")
	flow.handle(&"p2", "close_up")
	_assert_copy_matches("summary")


func test_a_copy_keeps_up_with_updates() -> void:
	_to_peek(2)
	var copy := _copy()
	flow.handle(&"p1", "ready")
	flow.handle(&"p2", "sit_out")
	copy.apply_flow(_json(flow.flow_dict()))
	assert_eq(copy.stage, DayFlow.Stage.BIDDING)
	assert_eq(_text(copy.flow_dict()), _text(flow.flow_dict()))


func test_a_copys_clocks_run_down_between_updates() -> void:
	_to_peek(1)
	var copy := _copy()
	copy.tick_clocks(5.0)
	assert_almost_eq(copy.peek_left, 15.0, 0.001)
	assert_almost_eq(flow.peek_left, 20.0, 0.001, "the host's own clock isn't touched")


func _to_peek(crew_size: int) -> void:
	controller.crew = Crew.of_size(crew_size)
	flow.start()
	flow.handle(Crew.HOST, "go_to_auction")


func _to_bidding(crew_size: int) -> void:
	_to_peek(crew_size)
	for member in controller.crew:
		flow.handle(member, "ready")
	assert_eq(flow.stage, DayFlow.Stage.BIDDING)


func _to_shop(crew_size: int) -> void:
	controller.crew = Crew.of_size(crew_size)
	flow.start()
	flow.handle(Crew.HOST, "skip_to_shop")
	assert_eq(flow.stage, DayFlow.Stage.SHOP)


## [param member] raises whenever outbid until the hammer falls.
func _win(member: StringName) -> void:
	for i in MAX_TICKS:
		if flow.stage != DayFlow.Stage.BIDDING:
			break
		if flow.auction.high_bidder != member:
			flow.handle(member, "raise")
		flow.tick(0.25)
	assert_eq(flow.winner, member)


## Gives the crew one of each kind and puts it on the shelves. Returns the uids.
func _stock(kinds: Array[StringName]) -> Array[int]:
	var uids: Array[int] = []
	for kind in kinds:
		var uid := controller.run.uids.next()
		controller.run.items[uid] = Fixture.item(uid, kind, 100)
		assert_true(flow.handle(Crew.HOST, "shelve", {"uid": uid}))
		uids.append(uid)
	return uids


func _copy() -> DayFlow:
	return DayFlow.mirror(catalog, _json(flow.run_dict()), _json(flow.today_dict()), _json(flow.flow_dict()))


func _assert_copy_matches(moment: String) -> void:
	var copy := _copy()
	assert_eq(copy.stage, flow.stage, moment)
	assert_eq(_text(copy.flow_dict()), _text(flow.flow_dict()), "%s: the flow" % moment)
	assert_eq(_text(copy.run_dict()), _text(flow.run_dict()), "%s: the run" % moment)
	assert_eq(_text(copy.today_dict()), _text(flow.today_dict()), "%s: today" % moment)


## Through JSON and back, the way data reaches another machine at worst.
func _json(data: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	return parsed


## A comparable text form: JSON with sorted keys, numbers normalised.
func _text(data: Dictionary) -> String:
	return JSON.stringify(_json(data), "", true)
