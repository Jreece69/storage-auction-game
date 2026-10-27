extends GutTest
## Shelves hold items up to their slot count; every shelved item has a tag.


func test_placing_uses_up_shelf_space() -> void:
	var shop := Shop.new(2, 3)
	assert_true(shop.place(1, 2, 0, 80))
	assert_eq(shop.free_space(0), 1)
	assert_eq(shop.free_space(1), 3)
	assert_true(shop.is_shelved(1))
	assert_eq(shop.price_of[1], 80)


func test_a_full_shelf_refuses_more() -> void:
	var shop := Shop.new(2, 3)
	shop.place(1, 2, 0, 80)
	assert_false(shop.place(2, 2, 0, 50), "only one slot left")
	assert_true(shop.place(2, 1, 0, 50))


func test_no_such_shelf() -> void:
	var shop := Shop.new(2, 3)
	assert_false(shop.place(1, 1, 2, 10))
	assert_false(shop.place(1, 1, -1, 10))


func test_an_item_sits_on_one_shelf_only() -> void:
	var shop := Shop.new(2, 3)
	shop.place(1, 1, 0, 10)
	assert_false(shop.place(1, 1, 1, 10))


func test_removing_frees_the_space() -> void:
	var shop := Shop.new(2, 3)
	shop.place(1, 3, 0, 10)
	shop.remove(1)
	assert_false(shop.is_shelved(1))
	assert_eq(shop.free_space(0), 3)


func test_prices_never_drop_below_a_dollar() -> void:
	var shop := Shop.new(2, 3)
	shop.place(1, 1, 0, 40)
	shop.set_price(1, 55)
	assert_eq(shop.price_of[1], 55)
	shop.set_price(1, -10)
	assert_eq(shop.price_of[1], 1)


func test_listing_is_in_a_stable_order() -> void:
	var shop := Shop.new(2, 3)
	shop.place(9, 1, 1, 10)
	shop.place(4, 1, 0, 10)
	shop.place(7, 1, 0, 10)
	assert_eq(shop.items_on(0), [4, 7] as Array[int])
	assert_eq(shop.shelved_uids(), [4, 7, 9] as Array[int])


func test_round_trip_through_a_dictionary() -> void:
	var shop := Shop.new(2, 3)
	shop.place(4, 2, 1, 120)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(shop.to_dict()))
	var restored := Shop.from_dict(saved)
	assert_eq(restored.shelf_count, 2)
	assert_eq(restored.shelf_of[4], 1)
	assert_eq(restored.price_of[4], 120)
	assert_eq(restored.free_space(1), 1)
