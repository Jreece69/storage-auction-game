extends Node
## A bot that plays one co-op day over the real network, for
## tools/coop_smoke.sh. Run one as the host and one or more as friends
## joining it; each makes its own player's moves through GameState.act, just
## as the screens do, and at the end-of-day summary writes its copy of the
## run and the day to $COOP_OUT so the script can check they all agree.
##
## The crew bids against each other on the first locker (friendly fire)
## until the host, given deep pockets, wins it; then they sit the rest out,
## load the van, serve customers at their own counters and close up
## together.
##
## Settings: $COOP_ROLE (host or join), $COOP_PORT, $COOP_NAME, and for the
## host $COOP_PLAYERS (how many to wait for) and $COOP_SEED.

## Gives up after this long, so a broken session fails instead of hanging.
const TIMEOUT_SECONDS: float = 90.0
## How many raises each bot makes on the first locker.
const RAISES: int = 2

var _role: String
var _out: String
var _players: int
var _started := false
var _finished := false
var _raised := 0
var _elapsed := 0.0
var _summary_wait := 0.0


func _ready() -> void:
	_role = OS.get_environment("COOP_ROLE")
	_out = OS.get_environment("COOP_OUT")
	_players = maxi(1, OS.get_environment("COOP_PLAYERS").to_int())
	var port := OS.get_environment("COOP_PORT").to_int()
	var player_name := OS.get_environment("COOP_NAME")
	# Speeds the auction clocks up; every machine runs its clocks the same.
	Engine.time_scale = 4.0
	Session.ended.connect(_on_ended)
	var err := Session.host(player_name, port) if _role == "host" else Session.join(player_name, "127.0.0.1", port)
	if err != OK:
		_fail("couldn't start the session: %s" % error_string(err))
	print("%s: %s on port %d" % [player_name, _role, port])


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta / Engine.time_scale
	if _elapsed > TIMEOUT_SECONDS:
		_fail("timed out at stage %s" % (str(GameState.flow.stage) if GameState.flow != null else "none"))
		return
	if _role == "host" and not _started:
		if Session.seated().size() >= _players:
			_started = true
			GameState.new_game(OS.get_environment("COOP_SEED").to_int())
			GameState.controller.run.cash = 100000
		return
	var flow := GameState.flow
	if flow == null or not flow.crew().has(GameState.local_member):
		return
	_play(flow, delta)


## One look at the day and at most one move, like a player.
func _play(flow: DayFlow, delta: float) -> void:
	var me := GameState.local_member
	var host := me == Crew.HOST
	match flow.stage:
		DayFlow.Stage.MAP:
			if host and flow.crew().size() >= _players:
				GameState.act("go_to_auction")
		DayFlow.Stage.PEEK:
			if not flow.ready.has(me):
				# Everyone bids on the first locker and sits the rest out.
				GameState.act("ready" if flow.locker.lot_number == 1 else "sit_out")
		DayFlow.Stage.BIDDING:
			var auction := flow.auction
			if auction.crew_out.has(me):
				return
			if auction.high_bidder == me or not auction.can_bid(me, auction.next_bid()):
				return
			if host or _raised < RAISES:
				_raised += 1
				GameState.act("raise")
			else:
				GameState.act("pass")
		DayFlow.Stage.RESULT:
			if host:
				GameState.act("continue")
		DayFlow.Stage.REVEAL:
			if host:
				GameState.act("show_all" if flow.revealed < flow.locker.items.size() else "load")
		DayFlow.Stage.HAUL:
			if not flow.ready.has(me):
				GameState.act("drive")
		DayFlow.Stage.MORNING_DONE:
			if host:
				GameState.act("open_shop")
		DayFlow.Stage.SHOP:
			_shop(flow, me, host)
		DayFlow.Stage.SUMMARY:
			# Give the last update a moment to reach everyone, then report.
			_summary_wait += delta
			if _summary_wait > 2.0:
				_finish(flow)


func _shop(flow: DayFlow, me: StringName, host: bool) -> void:
	var run := flow.controller.run
	if host and not run.backroom_uids().is_empty():
		GameState.act("shelve", {"uid": run.backroom_uids()[0]})
		return
	var counter := flow.counter_of(me)
	if counter.is_busy():
		GameState.act("accept")
	elif flow.more_customers() and not run.backroom_uids().size() > 0:
		GameState.act("next_customer")
	elif not flow.more_customers() and not flow.ready.has(me):
		GameState.act("close_up")


func _finish(flow: DayFlow) -> void:
	_finished = true
	var report := {
		"member": String(GameState.local_member),
		"crew": flow.flow_dict()["crew"],
		"run": flow.run_dict(),
		"today": flow.today_dict(),
		"summary": flow.controller.last_summary,
	}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true))
	file.close()
	print("%s: day over, crew of %d, cash %d" % [GameState.local_member, flow.crew().size(), flow.controller.run.cash])
	# The host stays a moment longer so nobody loses the connection early.
	await get_tree().create_timer(4.0 if _role == "host" else 0.5, true, false, true).timeout
	get_tree().quit()


func _on_ended(reason: String) -> void:
	if not _finished:
		_fail("the session ended: %s" % reason)


func _fail(message: String) -> void:
	_finished = true
	push_error("Co-op bot %s: %s" % [_role, message])
	get_tree().quit(1)
