class_name DayLedger
extends RefCounted
## The day's numbers, for the end-of-day summary.

var day: int
var start_cash: int
var spent_on_lockers: int = 0
var lockers_won: int = 0
## Lockers that went to a rival or went unsold.
var lockers_lost: int = 0
var sales: int = 0
var items_sold: int = 0
## Junk, and anything left behind at a locker, sold by weight.
var scrap: int = 0
var scrap_job: int = 0
var rent: int = 0
## The most valuable item found today, by market value.
var best_find_def: StringName = &""
var best_find_value: int = 0


func _init(p_day: int = 1, p_start_cash: int = 0) -> void:
	day = p_day
	start_cash = p_start_cash


func profit() -> int:
	return sales + scrap + scrap_job - spent_on_lockers - rent


## Remembers [param def_id] as today's best find if it beats the current one.
func note_find(def_id: StringName, value: int) -> void:
	if value > best_find_value:
		best_find_def = def_id
		best_find_value = value


func to_dict() -> Dictionary:
	return {
		"day": day,
		"start_cash": start_cash,
		"spent_on_lockers": spent_on_lockers,
		"lockers_won": lockers_won,
		"lockers_lost": lockers_lost,
		"sales": sales,
		"items_sold": items_sold,
		"scrap": scrap,
		"scrap_job": scrap_job,
		"rent": rent,
		"profit": profit(),
		"best_find_def": String(best_find_def),
		"best_find_value": best_find_value,
	}
