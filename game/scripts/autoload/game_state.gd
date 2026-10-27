extends Node
## The current run: money, day and progress. Phase 1 adds inventory, zones and
## net worth; for now it holds just enough to start, save and load a game.
##
## Money is whole dollars stored as int. Tuning numbers such as starting cash
## belong in game/data, so callers pass them in rather than this file
## hard-coding them.

var cash: int = 0
var day: int = 0


## Starts a fresh run. [param run_seed] drives every random roll in it.
func new_game(run_seed: int, starting_cash: int) -> void:
	Rng.reseed(run_seed)
	day = 1
	set_cash(starting_cash)
	EventBus.day_started.emit(day)


func set_cash(value: int) -> void:
	cash = value
	EventBus.cash_changed.emit(cash)


func to_dict() -> Dictionary:
	return {"cash": cash, "day": day}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 0))
	set_cash(int(data.get("cash", 0)))
