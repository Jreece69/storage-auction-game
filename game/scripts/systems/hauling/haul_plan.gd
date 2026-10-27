class_name HaulPlan
extends RefCounted
## Loading a won locker into the vehicle. Every item has a weight and a size,
## and the vehicle caps both. Whatever doesn't make it into the vehicle is
## left behind and sold for scrap by weight, along with the locker's junk.

var vehicle: VehicleDef
var items: Array[ItemInstance] = []

var _pricing: Pricing
var _selected: Dictionary[int, bool] = {}


func _init(p_vehicle: VehicleDef, p_items: Array[ItemInstance], pricing: Pricing) -> void:
	vehicle = p_vehicle
	items = p_items
	_pricing = pricing


func is_selected(uid: int) -> bool:
	return _selected.has(uid)


## Pounds already loaded.
func weight_used() -> int:
	var total := 0
	for item in selected_items():
		total += _pricing.def_of(item).weight
	return total


## Slots already loaded.
func volume_used() -> int:
	var total := 0
	for item in selected_items():
		total += _pricing.def_of(item).size
	return total


## Whether [param item] would still fit on top of what's loaded.
func fits(item: ItemInstance) -> bool:
	var def := _pricing.def_of(item)
	return weight_used() + def.weight <= vehicle.max_weight and volume_used() + def.size <= vehicle.max_volume


## Loads or unloads one item. Loading fails, returning false, if it won't fit.
func toggle(uid: int) -> bool:
	if _selected.has(uid):
		_selected.erase(uid)
		return true
	var item := _find(uid)
	if item == null or not fits(item):
		return false
	_selected[uid] = true
	return true


## Starts over and loads the best value for the space: items in order of
## value per share of the tighter limit (weight or space), skipping any that
## no longer fit.
func select_best() -> void:
	_selected.clear()
	var ranked := items.duplicate()
	ranked.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var a_density := _density(a)
		var b_density := _density(b)
		return a_density > b_density or (a_density == b_density and a.uid < b.uid))
	for item: ItemInstance in ranked:
		if fits(item):
			_selected[item.uid] = true


## The uids loaded so far, in the locker's order.
func selected_uids() -> Array[int]:
	var uids: Array[int] = []
	for item in selected_items():
		uids.append(item.uid)
	return uids


## Loads exactly [param uids], as another player's copy of the plan says.
func set_selected(uids: Array[int]) -> void:
	_selected.clear()
	for uid in uids:
		_selected[uid] = true


func selected_items() -> Array[ItemInstance]:
	var loaded: Array[ItemInstance] = []
	for item in items:
		if _selected.has(item.uid):
			loaded.append(item)
	return loaded


func left_behind() -> Array[ItemInstance]:
	var left: Array[ItemInstance] = []
	for item in items:
		if not _selected.has(item.uid):
			left.append(item)
	return left


## Scrap money for everything left behind plus [param junk_weight] pounds of junk.
func scrap_value(junk_weight: int) -> int:
	var total := _pricing.junk_value(junk_weight)
	for item in left_behind():
		total += _pricing.scrap_value(item)
	return total


func _density(item: ItemInstance) -> float:
	var def := _pricing.def_of(item)
	var share := maxf(float(def.weight) / vehicle.max_weight, float(def.size) / vehicle.max_volume)
	return _pricing.market_value(item) / maxf(share, 0.001)


func _find(uid: int) -> ItemInstance:
	for item in items:
		if item.uid == uid:
			return item
	return null
