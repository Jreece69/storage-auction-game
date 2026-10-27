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


func _set_for(seat: int) -> PackedInt32Array:
	if seat >= 0 and seat < visible_sets.size():
		return visible_sets[seat]
	return PackedInt32Array()
