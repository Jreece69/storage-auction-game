extends GutTest
## Market value follows condition and dirt; junk and scrap pay by the pound.
## Fixture numbers: good ×1, mint ×2, worn ×0.5, broken ×0.25, dirty ×0.5,
## scrap $0.10 per pound.

const Fixture := preload("res://tests/helpers/fixture.gd")

var pricing: Pricing


func before_each() -> void:
	pricing = Pricing.new(Fixture.catalog())


func test_market_value_follows_condition() -> void:
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"good")), 100)
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"mint")), 200)
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"worn")), 50)
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"broken")), 25)


func test_dirt_takes_a_discount() -> void:
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"good", true)), 50)
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 100, &"broken", true)), 13, "100 × 0.25 × 0.5 = 12.5 rounds to 13")


func test_nothing_is_worth_less_than_a_dollar() -> void:
	assert_eq(pricing.market_value(Fixture.item(1, &"chair", 1, &"broken", true)), 1)


func test_suggested_price_is_a_nice_round_number() -> void:
	assert_eq(pricing.suggested_price(Fixture.item(1, &"chair", 47)), 45)
	assert_eq(pricing.suggested_price(Fixture.item(1, &"chair", 236)), 240)
	assert_eq(pricing.suggested_price(Fixture.item(1, &"chair", 1)), 5, "never under the price step")


func test_junk_and_scrap_pay_by_the_pound() -> void:
	assert_eq(pricing.junk_value(100), 10)
	assert_eq(pricing.scrap_value(Fixture.item(1, &"anvil", 200)), 15, "the anvil weighs 150 lb")


func test_locker_value_adds_items_and_junk() -> void:
	var items: Array[ItemInstance] = [Fixture.item(1, &"chair", 100), Fixture.item(2, &"doll", 50)]
	assert_eq(pricing.locker_value(Fixture.locker(items, 100)), 160)
