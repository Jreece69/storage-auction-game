class_name Locker
extends RefCounted
## One storage unit up for auction: its theme, its contents, what shows
## through the open door, and where the auctioneer opens.

## Position in the morning's lineup, from 1.
var lot_number: int
var zone_id: StringName
var theme_id: StringName
var items: Array[ItemInstance] = []
## Items visible during the peek. The rest show as silhouettes.
var visible_uids: Array[int] = []
## Pounds of low-value junk, sold for scrap by weight.
var junk_weight: int
var opening_price: int


func is_visible(item: ItemInstance) -> bool:
	return visible_uids.has(item.uid)


func visible_items() -> Array[ItemInstance]:
	var shown: Array[ItemInstance] = []
	for item in items:
		if is_visible(item):
			shown.append(item)
	return shown


func hidden_count() -> int:
	return items.size() - visible_uids.size()


func find_item(uid: int) -> ItemInstance:
	for item in items:
		if item.uid == uid:
			return item
	return null
