class_name Locker
extends RefCounted
## One storage unit up for auction: its theme, its contents, what each crew
## member can see through the open door, and where the auctioneer opens.
##
## Each crew seat peeks from a different spot and sees a different third of
## the items, so a crew learns more by comparing notes. Four sets are always
## rolled, so a seed gives the same lockers whatever the crew size.

## Position in the morning's lineup, from 1.
var lot_number: int
var zone_id: StringName
var theme_id: StringName
var items: Array[ItemInstance] = []
## Per crew seat (index 0 is p1), the items that seat can see during the
## peek. The rest show as silhouettes.
var visible_sets: Array[PackedInt32Array] = []
## Pounds of low-value junk, sold for scrap by weight.
var junk_weight: int
var opening_price: int


func is_visible_to(item: ItemInstance, seat: int) -> bool:
	return _set_for(seat).has(item.uid)


## What [param seat] can see, in the locker's order.
func visible_items_for(seat: int) -> Array[ItemInstance]:
	var shown: Array[ItemInstance] = []
	for item in items:
		if is_visible_to(item, seat):
			shown.append(item)
	return shown


func hidden_count_for(seat: int) -> int:
	return items.size() - visible_items_for(seat).size()


## Everything the crew can see between them, seats 0 to [param crew_size] - 1.
func visible_to_crew(crew_size: int) -> Array[ItemInstance]:
	var shown: Array[ItemInstance] = []
	for item in items:
		for seat in crew_size:
			if is_visible_to(item, seat):
				shown.append(item)
				break
	return shown


func find_item(uid: int) -> ItemInstance:
	for item in items:
		if item.uid == uid:
			return item
	return null


## Everything about the locker as plain data, for sending to other players.
func to_dict() -> Dictionary:
	var item_data: Array = []
	for item in items:
		item_data.append(item.to_dict())
	var sets: Array = []
	for seen in visible_sets:
		sets.append(Array(seen))
	return {
		"lot": lot_number,
		"zone": String(zone_id),
		"theme": String(theme_id),
		"items": item_data,
		"visible": sets,
		"junk_weight": junk_weight,
		"opening_price": opening_price,
	}


static func from_dict(data: Dictionary) -> Locker:
	var locker := Locker.new()
	locker.lot_number = JsonValue.as_int(data["lot"])
	locker.zone_id = JsonValue.as_name(data["zone"])
	locker.theme_id = JsonValue.as_name(data["theme"])
	var item_data: Array = data["items"]
	for entry: Dictionary in item_data:
		locker.items.append(ItemInstance.from_dict(entry))
	var sets: Array = data["visible"]
	for seen: Array in sets:
		var uids := PackedInt32Array()
		for uid: Variant in seen:
			uids.append(JsonValue.as_int(uid))
		locker.visible_sets.append(uids)
	locker.junk_weight = JsonValue.as_int(data["junk_weight"])
	locker.opening_price = JsonValue.as_int(data["opening_price"])
	return locker


func _set_for(seat: int) -> PackedInt32Array:
	if seat >= 0 and seat < visible_sets.size():
		return visible_sets[seat]
	return PackedInt32Array()
