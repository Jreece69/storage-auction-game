class_name Shop
extends RefCounted
## The shop floor: shelves with slots, which item sits on which shelf, and
## each item's price tag. Anything the player owns that isn't on a shelf is
## in the back room.

var shelf_count: int
var slots_per_shelf: int
## Item uid → shelf index.
var shelf_of: Dictionary[int, int] = {}
## Item uid → price tag in dollars.
var price_of: Dictionary[int, int] = {}
## Item uid → slots it takes up.
var size_of: Dictionary[int, int] = {}


func _init(p_shelf_count: int = 4, p_slots_per_shelf: int = 3) -> void:
	shelf_count = p_shelf_count
	slots_per_shelf = p_slots_per_shelf


func is_shelved(uid: int) -> bool:
	return shelf_of.has(uid)


func free_space(shelf: int) -> int:
	var used := 0
	for uid in items_on(shelf):
		used += size_of[uid]
	return slots_per_shelf - used


func can_place(size: int, shelf: int) -> bool:
	return shelf >= 0 and shelf < shelf_count and size <= free_space(shelf)


## Puts an item on [param shelf] with a price tag. False if it doesn't fit.
func place(uid: int, size: int, shelf: int, price: int) -> bool:
	if is_shelved(uid) or not can_place(size, shelf):
		return false
	shelf_of[uid] = shelf
	size_of[uid] = size
	price_of[uid] = maxi(price, 1)
	return true


## Takes an item off its shelf (back to the back room, or sold).
func remove(uid: int) -> void:
	shelf_of.erase(uid)
	size_of.erase(uid)
	price_of.erase(uid)


func set_price(uid: int, price: int) -> void:
	if is_shelved(uid):
		price_of[uid] = maxi(price, 1)


## Items on [param shelf], oldest first.
func items_on(shelf: int) -> Array[int]:
	var found: Array[int] = []
	for uid: int in shelf_of:
		if shelf_of[uid] == shelf:
			found.append(uid)
	found.sort()
	return found


## Every shelved item, in a stable order.
func shelved_uids() -> Array[int]:
	var found: Array[int] = []
	for uid: int in shelf_of:
		found.append(uid)
	found.sort()
	return found


func to_dict() -> Dictionary:
	var placed: Array = []
	for uid in shelved_uids():
		placed.append({"uid": uid, "shelf": shelf_of[uid], "size": size_of[uid], "price": price_of[uid]})
	return {"shelves": shelf_count, "slots_per_shelf": slots_per_shelf, "placed": placed}


static func from_dict(data: Dictionary) -> Shop:
	var shop := Shop.new(JsonValue.as_int(data.get("shelves", 4)), JsonValue.as_int(data.get("slots_per_shelf", 3)))
	var placed: Array = data.get("placed", [])
	for entry: Dictionary in placed:
		var uid := JsonValue.as_int(entry["uid"])
		shop.shelf_of[uid] = JsonValue.as_int(entry["shelf"])
		shop.size_of[uid] = JsonValue.as_int(entry["size"])
		shop.price_of[uid] = JsonValue.as_int(entry["price"])
	return shop
