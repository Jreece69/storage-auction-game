extends GutTest
## Lockers are filled by the theme and zone weights, a third of the items
## show through the door, and one seed always rolls the same locker.

const Fixture := preload("res://tests/helpers/fixture.gd")

var catalog: Catalog
var roller: LootRoller
var zone: ZoneDef


func before_each() -> void:
	catalog = Fixture.catalog()
	roller = LootRoller.new(catalog)
	zone = catalog.zones[&"yard"]


func test_locker_follows_its_theme() -> void:
	var locker := roller.roll_locker(zone, 2, _rng(1), UidCounter.new())
	assert_eq(locker.theme_id, &"mixed")
	assert_eq(locker.lot_number, 2)
	assert_between(locker.items.size(), 4, 6)
	assert_eq(locker.junk_weight, 100)
	for item in locker.items:
		assert_has([&"furniture", &"toys", &"tools"], catalog.items[item.def_id].category)


func test_about_a_third_of_the_items_show() -> void:
	for seed_value in 20:
		var locker := roller.roll_locker(zone, 1, _rng(seed_value), UidCounter.new())
		var expected := clampi(roundi(locker.items.size() * 0.34), 1, locker.items.size())
		assert_eq(locker.visible_uids.size(), expected)
		assert_eq(locker.hidden_count(), locker.items.size() - expected)
		for uid in locker.visible_uids:
			assert_not_null(locker.find_item(uid))


func test_opening_price_is_value_times_the_zone_factor() -> void:
	# The fixture zone opens at exactly half of value (no noise).
	var pricing := Pricing.new(catalog)
	for seed_value in 10:
		var locker := roller.roll_locker(zone, 1, _rng(seed_value), UidCounter.new())
		var expected := maxi(10, Money.round_nice(pricing.locker_value(locker) * 0.5))
		assert_eq(locker.opening_price, expected)


func test_rolled_items_stay_inside_their_ranges() -> void:
	var rng := _rng(3)
	for i in 200:
		var doll := roller.roll_item(catalog.items[&"doll"], rng, i)
		assert_eq(doll.base_value, 50)
		assert_has([&"worn", &"good", &"mint"], doll.condition, "dolls are never broken")
		var lamp := roller.roll_item(catalog.items[&"lamp"], rng, i)
		assert_eq(lamp.condition, &"good", "lamps only come in good condition")


func test_zone_rarity_weights_decide_what_turns_up() -> void:
	# The yard gives legendary items zero weight, so the robot never appears.
	var uids := UidCounter.new()
	var rng := _rng(11)
	var kinds: Dictionary[StringName, int] = {}
	for i in 200:
		for item in roller.roll_locker(zone, 1, rng, uids).items:
			var count: int = kinds[item.def_id] if kinds.has(item.def_id) else 0
			kinds[item.def_id] = count + 1
	assert_false(kinds.has(&"robot"))
	assert_true(kinds.has(&"lamp"), "rare items do turn up")


func test_category_with_no_allowed_rarity_still_gives_an_item() -> void:
	var picky := ZoneDef.new()
	picky.rarity_weights = {&"rare": 1.0}
	var toy := roller.pick_item(&"toys", picky, _rng(5))
	assert_has([&"doll", &"robot"], toy.id)


func test_same_seed_same_locker() -> void:
	var first := roller.roll_locker(zone, 1, _rng(42), UidCounter.new())
	var second := roller.roll_locker(zone, 1, _rng(42), UidCounter.new())
	assert_eq(_describe(first), _describe(second))


func test_item_ids_are_unique_across_lockers() -> void:
	var uids := UidCounter.new()
	var seen: Array[int] = []
	var rng := _rng(8)
	for lot in range(1, 4):
		for item in roller.roll_locker(zone, lot, rng, uids).items:
			assert_does_not_have(seen, item.uid)
			seen.append(item.uid)


func test_real_content_rolls_sensible_lockers() -> void:
	var real := Content.catalog
	var real_roller := LootRoller.new(real)
	var real_zone: ZoneDef = real.zones[real.economy.starting_zone]
	var uids := UidCounter.new()
	var rng := _rng(2026)
	for i in 100:
		var locker := real_roller.roll_locker(real_zone, 1, rng, uids)
		var theme: LockerThemeDef = real.themes[locker.theme_id]
		assert_between(locker.items.size(), theme.item_count_min, theme.item_count_max)
		assert_gte(locker.opening_price, real.economy.auction.min_opening)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _describe(locker: Locker) -> Array:
	var description := [locker.theme_id, locker.junk_weight, locker.opening_price, locker.visible_uids]
	for item in locker.items:
		description.append(item.to_dict())
	return description
