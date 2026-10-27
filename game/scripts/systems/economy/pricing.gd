class_name Pricing
extends RefCounted
## What things are worth. An item's market value is what a fair buyer pays
## for it as it is: base value × condition, less a discount if it's dirty.

var catalog: Catalog


func _init(p_catalog: Catalog) -> void:
	catalog = p_catalog


func market_value(item: ItemInstance) -> int:
	var economy := catalog.economy
	var multiplier := economy.condition_multiplier(item.condition)
	if item.dirty:
		multiplier *= economy.dirty_multiplier
	return maxi(1, roundi(item.base_value * multiplier))


## The price tag the shop suggests: market value, rounded to a nice amount.
func suggested_price(item: ItemInstance) -> int:
	return maxi(catalog.economy.shop.price_step, Money.round_nice(market_value(item)))


## Scrap money for [param pounds] of junk.
func junk_value(pounds: int) -> int:
	return roundi(pounds * catalog.economy.scrap_per_pound)


## Scrap money for an item left behind or sold by weight.
func scrap_value(item: ItemInstance) -> int:
	return junk_value(def_of(item).weight)


## Everything in the locker at market value, plus its junk as scrap.
func locker_value(locker: Locker) -> int:
	var total := junk_value(locker.junk_weight)
	for item in locker.items:
		total += market_value(item)
	return total


func def_of(item: ItemInstance) -> ItemDef:
	return catalog.items[item.def_id]
