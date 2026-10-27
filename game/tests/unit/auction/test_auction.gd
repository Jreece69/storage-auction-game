extends GutTest
## The auction: opening bid, minimum raises, the countdown that resets on
## every bid, rivals who fold past their max, jump bids that scare a rookie,
## and the cash limit. The countdown here is 6 seconds, so "going once"
## comes at 2 seconds and "going twice" at 4.

var rules: AuctionRules
var rng: RandomNumberGenerator


func before_each() -> void:
	rules = AuctionRules.new()
	rules.countdown_seconds = 6.0
	rng = RandomNumberGenerator.new()
	rng.seed = 1


func test_first_bid_is_the_opening_price() -> void:
	var auction := Auction.new(rules, 100, [] as Array[RivalBidder], 1000, rng)
	assert_eq(auction.next_bid(), 100)
	auction.player_raise()
	assert_eq(auction.price, 100)
	assert_eq(auction.high_bidder, Auction.PLAYER)


func test_minimum_raise_is_about_five_percent() -> void:
	assert_eq(rules.raise_amount(10), 5, "never under $5")
	assert_eq(rules.raise_amount(105), 5)
	assert_eq(rules.raise_amount(300), 15)
	assert_eq(rules.raise_amount(2000), 100)
	assert_eq(rules.jump_amount(100), 25, "a quarter of the price")
	assert_eq(rules.jump_amount(40), 15, "at least three minimum raises")


func test_countdown_calls_twice_then_sells() -> void:
	var auction := Auction.new(rules, 100, [] as Array[RivalBidder], 1000, rng)
	auction.player_raise()
	assert_eq(_types(auction.advance(1.9)), [] as Array[String])
	assert_eq(_types(auction.advance(0.2)), ["call"] as Array[String], "going once at 2 seconds")
	assert_eq(_types(auction.advance(2.0)), ["call"] as Array[String], "going twice at 4 seconds")
	var last := auction.advance(2.0)
	assert_eq(_types(last), ["sold"] as Array[String])
	assert_eq(auction.winner(), Auction.PLAYER)
	assert_eq(JsonValue.as_int(last[0]["amount"]), 100)


func test_every_bid_resets_the_countdown() -> void:
	var rival := _rival(&"rival", 1000, 5.0)
	var auction := Auction.new(rules, 100, [rival] as Array[RivalBidder], 1000, rng)
	auction.player_raise()
	var events := auction.advance(5.0)
	assert_eq(_types(events), ["call", "call", "bid"] as Array[String], "the rival answers at the last moment")
	assert_eq(auction.high_bidder, &"rival")
	assert_eq(auction.price, 105)
	assert_almost_eq(auction.countdown, 6.0, 0.001)


func test_nobody_bids_and_the_locker_goes_unsold() -> void:
	var cheap := _rival(&"cheap", 50, 1.0)
	var auction := Auction.new(rules, 100, [cheap] as Array[RivalBidder], 1000, rng)
	assert_eq(_types(auction.run_to_end()), ["fold", "call", "call", "unsold"] as Array[String])
	assert_eq(auction.state, Auction.State.UNSOLD)
	assert_eq(auction.winner(), Auction.NOBODY)


func test_rivals_bid_each_other_up_until_one_folds() -> void:
	var low := _rival(&"low", 130, 1.0)
	var high := _rival(&"high", 200, 2.0)
	var auction := Auction.new(rules, 100, [low, high] as Array[RivalBidder], 1000, rng)
	auction.player_pass()
	auction.run_to_end()
	assert_true(low.folded)
	assert_eq(auction.winner(), &"high")
	assert_eq(auction.price, 135, "one raise past the $130 the low bidder would pay")


func test_player_cannot_bid_more_than_their_cash() -> void:
	var auction := Auction.new(rules, 100, [] as Array[RivalBidder], 90, rng)
	assert_false(auction.can_player_bid(auction.next_bid()))
	assert_eq(auction.player_raise().size(), 0)
	assert_eq(auction.high_bidder, Auction.NOBODY)


func test_player_cannot_outbid_themselves() -> void:
	var auction := Auction.new(rules, 100, [] as Array[RivalBidder], 1000, rng)
	auction.player_raise()
	assert_eq(auction.player_raise().size(), 0)
	assert_eq(auction.price, 100)


func test_jump_bid_scares_off_a_rookie_but_not_a_shark() -> void:
	var rookie := _rival(&"rookie", 1000, 1.0, 1.0)
	var shark := _rival(&"shark", 1000, 2.0, 0.0)
	var auction := Auction.new(rules, 100, [rookie, shark] as Array[RivalBidder], 5000, rng)
	var events := auction.player_jump()
	assert_eq(auction.price, 125)
	assert_eq(_types(events), ["bid", "fold"] as Array[String])
	assert_true(rookie.folded)
	assert_false(shark.folded)


func test_after_passing_the_rivals_settle_it() -> void:
	var a := _rival(&"a", 300, 1.0)
	var b := _rival(&"b", 220, 1.5)
	var auction := Auction.new(rules, 100, [a, b] as Array[RivalBidder], 1000, rng)
	auction.player_pass()
	auction.run_to_end()
	assert_eq(auction.winner(), &"a")
	assert_between(auction.price, 220, 300, "pays a little over the runner-up, never past their max")


func test_same_seed_same_auction() -> void:
	assert_eq(_scripted_run(77), _scripted_run(77))
	assert_ne(_scripted_run(77), _scripted_run(78), "a different seed changes the timings")


## Rivals with a spread of reaction times, so the seed matters.
func _scripted_run(seed_value: int) -> Array[Dictionary]:
	var seeded := RandomNumberGenerator.new()
	seeded.seed = seed_value
	var a := _rival(&"a", 400, 0.5)
	a.def.reaction_max = 3.0
	var b := _rival(&"b", 380, 0.5)
	b.def.reaction_max = 3.0
	var auction := Auction.new(rules, 100, [a, b] as Array[RivalBidder], 1000, seeded)
	var events := auction.advance(0.7)
	events.append_array(auction.player_raise())
	events.append_array(auction.run_to_end())
	return events


func _rival(id: StringName, max_bid: int, reaction: float, jump_fold: float = 0.0) -> RivalBidder:
	var def := RivalDef.new()
	def.id = id
	def.reaction_min = reaction
	def.reaction_max = reaction
	def.jump_fold_chance = jump_fold
	return RivalBidder.new(def, max_bid)


func _types(events: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for event in events:
		types.append(str(event["type"]))
	return types
