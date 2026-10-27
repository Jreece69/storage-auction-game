extends Node
## The game in progress. Holds the RunController for the running game (the
## rules live there and in the other systems) and the DayFlow that plays the
## day, and forwards their signals to EventBus. Scenes reach the run through
## here; systems never do.
##
## Scenes make the local player's moves with [method act], which names the
## move, never the player: the crew member is always this machine's.
##
## In co-op the host's machine holds the real run. A joined player's machine
## holds a copy from the host (see Session), shows it, and sends its moves
## to the host instead of making them.

var controller: RunController = null
var flow: DayFlow = null
## Which crew member this machine plays. Solo play is always p1, the host.
var local_member: StringName = Crew.HOST

var cash: int:
	get:
		return controller.run.cash if controller != null else 0

var day: int:
	get:
		return controller.run.day if controller != null else 0


func has_run() -> bool:
	return controller != null


## This machine's crew seat: 0 for p1, the host.
func local_seat() -> int:
	return Crew.seat_of(local_member)


## Starts a fresh run. [param run_seed] drives every random roll in it.
func new_game(run_seed: int) -> void:
	Rng.reseed(run_seed)
	_attach(RunController.new_run(Content.catalog, Rng.streams))


## Resumes a run from [method snapshot], at the start of its day.
func load_snapshot(snapshot_data: Dictionary) -> void:
	_attach(RunController.from_snapshot(Content.catalog, Rng.streams, snapshot_data))


## What a save holds: the run and the random streams at the start of today.
func snapshot() -> Dictionary:
	return controller.day_start_snapshot if controller != null else {}


## Drops the run in progress, for quitting to the title screen.
func end_run() -> void:
	controller = null
	flow = null


## Makes a move for this machine's player (see DayFlow.handle). Returns
## whether it went through. A joined player's move goes to the host, and
## counts as going through: the host's next update shows what happened.
func act(command: String, args: Dictionary = {}) -> bool:
	if flow == null:
		return false
	if Session.is_client():
		Session.send_move(command, args)
		return true
	return flow.handle(local_member, command, args)


## Shows a copy of the host's day (see Session). The copy never runs the
## rules; only its clocks tick, between the host's updates.
func adopt_copy(copy: DayFlow) -> void:
	controller = copy.controller
	flow = copy
	flow.changed.connect(EventBus.flow_changed.emit)
	EventBus.cash_changed.emit(controller.run.cash)
	EventBus.flow_changed.emit()


func _process(delta: float) -> void:
	if flow == null:
		return
	if Session.is_client():
		flow.tick_clocks(delta)
	else:
		flow.tick(delta)


func _attach(new_controller: RunController) -> void:
	controller = new_controller
	controller.cash_changed.connect(EventBus.cash_changed.emit)
	controller.day_started.connect(EventBus.day_started.emit)
	controller.locker_settled.connect(EventBus.locker_settled.emit)
	controller.item_sold.connect(EventBus.item_sold.emit)
	controller.day_ended.connect(EventBus.day_ended.emit)
	flow = DayFlow.new(controller)
	flow.changed.connect(EventBus.flow_changed.emit)
	flow.auction_events.connect(EventBus.auction_events.emit)
	flow.day_closed.connect(_on_day_closed)
	EventBus.cash_changed.emit(controller.run.cash)
	flow.start()


## The shop has closed: save, so the next session starts tomorrow.
func _on_day_closed() -> void:
	SaveManager.save_game(SaveManager.AUTOSAVE)
