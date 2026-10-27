class_name LootRoller
extends RefCounted
## Fills lockers. For each one: a theme by the zone's weights, an item count
## from the theme, then for each item a category by the theme's weights and a
## kind by the zone's rarity weights, and finally its value, condition and
## dirt. It also picks the third of the items that show through the door and
## the auctioneer's opening price.

var catalog: Catalog
var pricing: Pricing


func _init(p_catalog: Catalog) -> void:
	catalog = p_catalog
	pricing = Pricing.new(p_catalog)


func roll_locker(zone: ZoneDef, lot_number: int, rng: RandomNumberGenerator, uids: UidCounter) -> Locker:
	var theme_id: StringName = Weighted.pick(zone.theme_weights, rng)
	var theme: LockerThemeDef = catalog.themes[theme_id]
	var locker := Locker.new()
	locker.lot_number = lot_number
	locker.zone_id = zone.id
	locker.theme_id = theme_id
	var count := rng.randi_range(theme.item_count_min, theme.item_count_max)
	for i in count:
		var category: StringName = Weighted.pick(theme.category_weights, rng)
		locker.items.append(roll_item(pick_item(category, zone, rng), rng, uids.next()))
	locker.junk_weight = rng.randi_range(theme.junk_weight_min, theme.junk_weight_max)
	_choose_visible(locker, rng)
	locker.opening_price = _opening_price(locker, zone, rng)
	return locker


## One item of [param def] with its value, condition and dirt rolled.
func roll_item(def: ItemDef, rng: RandomNumberGenerator, uid: int) -> ItemInstance:
	var base_value := rng.randi_range(def.value_min, def.value_max)
	var economy := catalog.economy
	var lowest := economy.condition_index(def.condition_min)
	var highest := economy.condition_index(def.condition_max)
	var weights: Dictionary[StringName, float] = {}
	for index in range(lowest, highest + 1):
		var condition := economy.condition_order[index]
		weights[condition] = economy.condition_weights[condition]
	var picked: Variant = Weighted.pick(weights, rng)
	# Only possible if the data gives every allowed condition zero weight.
	var condition: StringName = def.condition_max if picked == null else picked
	var dirty := rng.randf() < economy.dirty_chance
	return ItemInstance.new(uid, def.id, base_value, condition, dirty)


## A kind of item from [param category], weighted by how common its rarity is
## in [param zone]. Falls back to an even pick if the zone allows none of them.
func pick_item(category: StringName, zone: ZoneDef, rng: RandomNumberGenerator) -> ItemDef:
	var choices := catalog.items_in_category(category)
	var weights: Dictionary[StringName, float] = {}
	for def in choices:
		weights[def.id] = zone.rarity_weights[def.rarity] if zone.rarity_weights.has(def.rarity) else 0.0
	var picked: Variant = Weighted.pick(weights, rng)
	if picked == null:
		return choices[rng.randi_range(0, choices.size() - 1)]
	var id: StringName = picked
	return catalog.items[id]


## Each crew seat gets its own random third of the items to see.
func _choose_visible(locker: Locker, rng: RandomNumberGenerator) -> void:
	var count := clampi(roundi(locker.items.size() * catalog.economy.auction.visible_share), 1, locker.items.size())
	for seat in Crew.MAX:
		var order: Array[int] = []
		for i in locker.items.size():
			order.append(i)
		# Fisher-Yates with the loot stream, never Array.shuffle().
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := order[i]
			order[i] = order[j]
			order[j] = swap
		var seen := PackedInt32Array()
		for i in count:
			seen.append(locker.items[order[i]].uid)
		locker.visible_sets.append(seen)


func _opening_price(locker: Locker, zone: ZoneDef, rng: RandomNumberGenerator) -> int:
	var noise := rng.randf_range(zone.opening_noise_min, zone.opening_noise_max)
	var opening := Money.round_nice(pricing.locker_value(locker) * zone.opening_factor * noise)
	return maxi(catalog.economy.auction.min_opening, opening)
