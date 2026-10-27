extends GutTest
## Haggling with the fixture's customer: their limit is exactly the item's
## market value, they open at half of it (or of the tag, if lower), close half
## the gap after each counter that's too high, sit through two such counters,
## and won't even offer when the tag is over twice their limit.

const Fixture := preload("res://tests/helpers/fixture.gd")

var haggler: CustomerDef
var rng: RandomNumberGenerator


func before_each() -> void:
	haggler = Fixture.catalog().customers[&"haggler"]
	rng = RandomNumberGenerator.new()
	rng.seed = 3


func test_opening_offer_is_below_their_limit() -> void:
	var customer := _approach(100, 100)
	assert_true(customer.is_offering())
	assert_eq(customer.limit, 100)
	assert_eq(customer.offer, 50)


func test_low_tag_lowers_the_opening_offer() -> void:
	assert_eq(_approach(60, 100).offer, 30)


func test_taking_the_offer_sells_at_it() -> void:
	var customer := _approach(100, 100)
	assert_eq(customer.accept(), 50)
	assert_eq(customer.state, Customer.State.SOLD)


func test_a_counter_within_their_limit_is_accepted() -> void:
	var customer := _approach(100, 100)
	assert_eq(customer.counter(90), "accept")
	assert_eq(customer.offer, 90)
	assert_eq(customer.state, Customer.State.SOLD)


func test_counters_too_high_edge_them_up_then_they_leave() -> void:
	var customer := _approach(100, 100)
	assert_eq(customer.counter(150), "raise")
	assert_eq(customer.offer, 75, "half the gap from 50 to 100")
	assert_eq(customer.counter(150), "raise")
	assert_eq(customer.offer, 90, "half the gap again, rounded")
	assert_eq(customer.counter(150), "leave")
	assert_eq(customer.state, Customer.State.LEFT)
	assert_eq(customer.reason, Customer.Reason.LOST_PATIENCE)


func test_a_wild_price_tag_sends_them_away() -> void:
	var customer := _approach(250, 100)
	assert_eq(customer.state, Customer.State.LEFT)
	assert_eq(customer.reason, Customer.Reason.TOO_PRICEY)


func test_some_customers_only_browse() -> void:
	var browser := haggler.duplicate() as CustomerDef
	browser.interest_chance = 0.0
	var customer := Customer.approach(browser, 1, 100, 100, 5, rng)
	assert_eq(customer.reason, Customer.Reason.BROWSING)


func test_declining_sends_them_away() -> void:
	var customer := _approach(100, 100)
	customer.decline()
	assert_eq(customer.state, Customer.State.LEFT)
	assert_eq(customer.reason, Customer.Reason.DECLINED)


func _approach(tag: int, market_value: int) -> Customer:
	return Customer.approach(haggler, 1, tag, market_value, 5, rng)
