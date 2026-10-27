extends GutTest
## The vehicle caps weight and space; what doesn't fit is scrapped by weight.
## The fixture van carries 100 lb in 4 slots. Chair 30 lb / 2 slots,
## lamp 10 lb / 1, doll 2 lb / 1, anvil 150 lb / 3. Scrap pays $0.10 a pound.

const Fixture := preload("res://tests/helpers/fixture.gd")

var catalog: Catalog
var pricing: Pricing
var van: VehicleDef


func before_each() -> void:
	catalog = Fixture.catalog()
	pricing = Pricing.new(catalog)
	van = catalog.vehicles[&"van"]


func test_loading_tracks_weight_and_space() -> void:
	var plan := _plan([Fixture.item(1, &"chair", 100), Fixture.item(2, &"lamp", 400)])
	assert_true(plan.toggle(1))
	assert_true(plan.toggle(2))
	assert_eq(plan.weight_used(), 40)
	assert_eq(plan.volume_used(), 3)


func test_too_heavy_is_refused() -> void:
	var plan := _plan([Fixture.item(1, &"anvil", 200)])
	assert_false(plan.toggle(1), "150 lb won't go in a 100 lb van")
	assert_false(plan.is_selected(1))


func test_out_of_space_is_refused() -> void:
	var plan := _plan([Fixture.item(1, &"chair", 100), Fixture.item(2, &"chair", 100), Fixture.item(3, &"doll", 50)])
	assert_true(plan.toggle(1))
	assert_true(plan.toggle(2))
	assert_false(plan.toggle(3), "two chairs fill all 4 slots")


func test_toggling_again_unloads() -> void:
	var plan := _plan([Fixture.item(1, &"chair", 100)])
	plan.toggle(1)
	assert_true(plan.toggle(1))
	assert_false(plan.is_selected(1))
	assert_eq(plan.weight_used(), 0)


func test_best_load_puts_value_first() -> void:
	# The lamp is worth the most per slot, then the chair and the doll tie;
	# the second chair no longer fits once those are in.
	var plan := _plan([Fixture.item(1, &"chair", 100), Fixture.item(2, &"chair", 100), Fixture.item(3, &"lamp", 400), Fixture.item(4, &"doll", 50), Fixture.item(5, &"anvil", 200)])
	plan.select_best()
	assert_eq(_uids(plan.selected_items()), [1, 3, 4] as Array[int])
	assert_eq(_uids(plan.left_behind()), [2, 5] as Array[int])


func test_left_behind_and_junk_are_scrapped_by_weight() -> void:
	var plan := _plan([Fixture.item(1, &"chair", 100), Fixture.item(2, &"anvil", 200)])
	plan.toggle(1)
	# The anvil (150 lb) plus 100 lb of junk: 250 lb at $0.10.
	assert_eq(plan.scrap_value(100), 25)


func _plan(items: Array[ItemInstance]) -> HaulPlan:
	return HaulPlan.new(van, items, pricing)


func _uids(items: Array[ItemInstance]) -> Array[int]:
	var uids: Array[int] = []
	for item in items:
		uids.append(item.uid)
	return uids
