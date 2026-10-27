extends GutTest
## A run survives the trip through a save file intact.

const Fixture := preload("res://tests/helpers/fixture.gd")

var economy: EconomyDef


func before_each() -> void:
	economy = Fixture.catalog().economy


func test_fresh_run_starts_from_the_economy_data() -> void:
	var run := RunState.fresh(economy)
	assert_eq(run.day, 1)
	assert_eq(run.cash, 1000)
	assert_eq(run.zone_id, &"yard")
	assert_eq(run.vehicle_id, &"van")
	assert_eq(run.shop.shelf_count, 2)


func test_round_trip_through_json() -> void:
	var run := RunState.fresh(economy)
	run.day = 5
	run.cash = 432
	run.uids.next_uid = 17
	run.items[3] = Fixture.item(3, &"chair", 90, &"worn", true)
	run.items[8] = Fixture.item(8, &"lamp", 400, &"good")
	run.shop.place(8, 1, 1, 380)
	run.lockers_won = 2
	run.best_find_def = &"lamp"
	run.best_find_value = 400

	var saved: Dictionary = JSON.parse_string(JSON.stringify(run.to_dict()))
	var restored := RunState.from_dict(saved, economy)

	assert_eq(restored.to_dict(), run.to_dict())
	assert_eq(restored.items[3].condition, &"worn")
	assert_true(restored.items[3].dirty)
	assert_eq(restored.backroom_uids(), [3] as Array[int])
	assert_eq(restored.shop.price_of[8], 380)


func test_missing_fields_fall_back_to_the_start() -> void:
	var restored := RunState.from_dict({"day": 4, "cash": 321}, economy)
	assert_eq(restored.day, 4)
	assert_eq(restored.cash, 321)
	assert_eq(restored.vehicle_id, &"van")
	assert_eq(restored.items.size(), 0)
