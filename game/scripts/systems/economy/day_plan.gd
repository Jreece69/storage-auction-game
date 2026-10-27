class_name DayPlan
extends RefCounted
## One day as it unfolds: the morning's lockers and rivals, then the
## afternoon's shoppers, with the ledger for the end-of-day summary.

enum Phase { MORNING, AFTERNOON, DONE }

var day: int
var phase: Phase = Phase.MORNING
var lockers: Array[Locker] = []
var roster: RivalRoster
var ledger: DayLedger
## Lot number → who won it: a crew member, a rival id, or Auction.NOBODY.
var results: Dictionary[int, StringName] = {}
var customers_left: int = 0


func _init(p_day: int, start_cash: int) -> void:
	day = p_day
	ledger = DayLedger.new(p_day, start_cash)


func is_settled(locker: Locker) -> bool:
	return results.has(locker.lot_number)


## Today so far as plain data, for sending to other players.
func to_dict() -> Dictionary:
	var locker_data: Array = []
	for locker in lockers:
		locker_data.append(locker.to_dict())
	var settled: Array = []
	for lot: int in results:
		settled.append([lot, String(results[lot])])
	return {
		"day": day,
		"phase": phase,
		"lockers": locker_data,
		"roster": roster.to_dict() if roster != null else {},
		"ledger": ledger.to_dict(),
		"results": settled,
		"customers_left": customers_left,
	}


static func from_dict(data: Dictionary, catalog: Catalog) -> DayPlan:
	var ledger_data: Dictionary = data.get("ledger", {})
	var plan := DayPlan.new(JsonValue.as_int(data.get("day", 1)), 0)
	plan.ledger = DayLedger.from_dict(ledger_data)
	plan.phase = JsonValue.as_int(data.get("phase", Phase.MORNING)) as Phase
	var locker_data: Array = data.get("lockers", [])
	for entry: Dictionary in locker_data:
		plan.lockers.append(Locker.from_dict(entry))
	var roster_data: Dictionary = data.get("roster", {})
	plan.roster = RivalRoster.from_dict(roster_data, catalog)
	var settled: Array = data.get("results", [])
	for pair: Array in settled:
		plan.results[JsonValue.as_int(pair[0])] = JsonValue.as_name(pair[1])
	plan.customers_left = JsonValue.as_int(data.get("customers_left", 0))
	return plan


## The next locker still to be auctioned, or null when the morning is over.
func next_locker() -> Locker:
	for locker in lockers:
		if not is_settled(locker):
			return locker
	return null
