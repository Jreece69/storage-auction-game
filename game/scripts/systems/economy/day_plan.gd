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


## The next locker still to be auctioned, or null when the morning is over.
func next_locker() -> Locker:
	for locker in lockers:
		if not is_settled(locker):
			return locker
	return null
