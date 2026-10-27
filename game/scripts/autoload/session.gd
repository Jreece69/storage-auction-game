extends Node
## Playing together over the network. One player hosts and runs the real
## day (DayFlow); up to three friends join, see copies of it, and send their
## moves to the host. Solo play is offline: no network at all, and the local
## player is both host and only crew member.
##
## The host is the referee: only its game rolls dice or applies a rule.
## Players join by IP over ENet for now (LAN, or a forwarded port); Steam
## lobbies replace the transport later, behind the same calls.
##
## What travels: a joining player's name, each player's moves (a command and
## its arguments), and from the host the run, today and the flow as plain
## data, plus the auction's events for the feed. Friends who join mid-day
## watch until the next day starts, then join the crew.

## Who's in the session changed (someone joined, left or was seated).
signal roster_changed
## This machine got a seat from the host.
signal joined
## The session ended for this machine. [param reason] is a translation key.
signal ended(reason: String)

enum Mode { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT: int = 47100
## How often the host sends the running clocks while they run.
const SYNC_INTERVAL: float = 0.1

var mode: Mode = Mode.OFFLINE
## Who's playing, by crew seat (member id → name). The host is p1.
var names: Dictionary[StringName, String] = {}
## This player's name, sent when joining.
var local_name: String = ""
## Why the last session ended, for the title screen (a translation key).
var last_end_reason: String = ""

## Host only: each connected peer's seat.
var _member_of_peer: Dictionary[int, StringName] = {}
## Host only: what was last sent on each channel, to send only changes,
## and for which run.
var _sent: Dictionary[String, String] = {}
var _sent_for: DayFlow = null
var _sync_wait: float = 0.0
## Client only: channels received before the first full copy is built.
var _pending: Dictionary[String, Dictionary] = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	EventBus.flow_changed.connect(_on_flow_changed)
	EventBus.auction_events.connect(_on_auction_events)


func is_online() -> bool:
	return mode != Mode.OFFLINE


## Whether this machine runs the real day: the host, or anyone playing solo.
func is_host() -> bool:
	return mode != Mode.CLIENT


func is_client() -> bool:
	return mode == Mode.CLIENT


## The name of crew member [param member], or "Player N" if they haven't one.
func name_of(member: StringName) -> String:
	if names.has(member) and not names[member].is_empty():
		return names[member]
	return tr("UI_PLAYER") % (Crew.seat_of(member) + 1)


## The members seated right now, in seat order.
func seated() -> Array[StringName]:
	var members: Array[StringName] = []
	for seat in Crew.MAX:
		var member := Crew.member_id(seat)
		if names.has(member):
			members.append(member)
	return members


# --- Starting and leaving -----------------------------------------------------

## Opens a session on [param port] for friends to join, with this machine as
## p1.
func host(player_name: String, port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Crew.MAX - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	# Everything goes through the host, so players never need telling about
	# each other's connections (and telling one who's leaving fails).
	var scene_multiplayer := multiplayer as SceneMultiplayer
	if scene_multiplayer != null:
		scene_multiplayer.server_relay = false
	mode = Mode.HOST
	local_name = player_name
	GameState.local_member = Crew.HOST
	names = {Crew.HOST: player_name}
	_member_of_peer.clear()
	_sent.clear()
	roster_changed.emit()
	return OK


## Connects to a host at [param address]. [signal joined] follows once the
## host gives this machine a seat, or [signal ended] if it can't.
func join(player_name: String, address: String, port: int = DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	local_name = player_name
	names.clear()
	_pending.clear()
	return OK


## Leaves the session, or closes it for everyone when hosting. Back to solo.
func leave() -> void:
	if mode == Mode.OFFLINE:
		return
	var was_client := mode == Mode.CLIENT
	mode = Mode.OFFLINE
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	names.clear()
	_member_of_peer.clear()
	_sent.clear()
	_pending.clear()
	GameState.local_member = Crew.HOST
	if was_client:
		GameState.end_run()
	roster_changed.emit()


# --- Moves -----------------------------------------------------------------------

## Sends this player's move to the host (see GameState.act).
func send_move(command: String, args: Dictionary) -> void:
	if mode == Mode.CLIENT:
		_move.rpc_id(1, command, args)


@rpc("any_peer", "call_remote", "reliable")
func _move(command: String, args: Dictionary) -> void:
	if mode != Mode.HOST or GameState.flow == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not _member_of_peer.has(sender):
		return
	GameState.flow.handle(_member_of_peer[sender], command, args)


# --- The host: seats -------------------------------------------------------------

func _on_peer_connected(_peer_id: int) -> void:
	# Nothing to do until they say hello with their name.
	pass


@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String, version: String) -> void:
	if mode != Mode.HOST:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if version != _version():
		_refuse.rpc_id(peer_id, "SESSION_WRONG_VERSION")
		return
	var seat := _free_seat()
	if seat < 0:
		_refuse.rpc_id(peer_id, "SESSION_FULL")
		return
	var member := Crew.member_id(seat)
	_member_of_peer[peer_id] = member
	names[member] = player_name
	_welcome.rpc_id(peer_id, String(member))
	_send_names()
	_crew_up_if_starting()
	if GameState.flow != null:
		_send_everything(peer_id)
	roster_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	# The peer is still half there while this signal runs, and sending to it
	# fails; carry on once it's gone.
	_drop_peer.call_deferred(peer_id)


func _drop_peer(peer_id: int) -> void:
	if mode != Mode.HOST or not _member_of_peer.has(peer_id):
		return
	var member := _member_of_peer[peer_id]
	_member_of_peer.erase(peer_id)
	names.erase(member)
	if GameState.flow != null:
		GameState.flow.drop_member(member)
	_send_names()
	roster_changed.emit()


func _free_seat() -> int:
	for seat in range(1, Crew.MAX):
		if not names.has(Crew.member_id(seat)):
			return seat
	return -1


func _send_names() -> void:
	var data: Dictionary = {}
	for member: StringName in names:
		data[String(member)] = names[member]
	for peer_id in _connected_peers():
		_set_names.rpc_id(peer_id, data)


## The seated players whose connection is fully up. Sending to one that's
## halfway out fails, and two friends can leave in the same moment.
func _connected_peers() -> Array[int]:
	var peers: Array[int] = []
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var listed := multiplayer.get_peers()
	for peer_id: int in _member_of_peer:
		if not listed.has(peer_id):
			continue
		if enet != null:
			var link := enet.get_peer(peer_id)
			if link == null or link.get_state() != ENetPacketPeer.STATE_CONNECTED:
				continue
		peers.append(peer_id)
	return peers


## At the start of a day (or before the run), everyone seated is in the crew.
## Friends who join mid-day wait for the next one.
func _crew_up_if_starting() -> void:
	var flow := GameState.flow
	if flow == null or flow.stage != DayFlow.Stage.MAP:
		return
	var members := seated()
	if flow.controller.crew != members:
		flow.controller.crew = members
		flow.changed.emit()


# --- The host: sending the day ------------------------------------------------------

func _process(delta: float) -> void:
	if mode != Mode.HOST or GameState.flow == null or _member_of_peer.is_empty():
		return
	var stage := GameState.flow.stage
	if stage == DayFlow.Stage.PEEK or stage == DayFlow.Stage.BIDDING or stage == DayFlow.Stage.REVEAL:
		_sync_wait -= delta
		if _sync_wait <= 0.0:
			_sync_wait = SYNC_INTERVAL
			_send_changes()


func _on_flow_changed() -> void:
	if mode != Mode.HOST or GameState.flow == null:
		return
	_crew_up_if_starting()
	_send_changes()


func _on_auction_events(events: Array[Dictionary]) -> void:
	if mode != Mode.HOST:
		return
	for peer_id in _connected_peers():
		_auction_events.rpc_id(peer_id, events)


## Sends whatever changed since the last send to everyone.
func _send_changes() -> void:
	if _member_of_peer.is_empty():
		return
	var flow := GameState.flow
	if flow != _sent_for:
		# A new run: everyone needs all of it.
		_sent.clear()
		_sent_for = flow
	var channels := {"run": flow.run_dict(), "today": flow.today_dict(), "flow": flow.flow_dict()}
	for channel: String in channels:
		var data: Dictionary = channels[channel]
		var text := JSON.stringify(data, "", true)
		if _sent.get(channel, "") != text:
			_sent[channel] = text
			for peer_id in _connected_peers():
				_sync.rpc_id(peer_id, channel, data)


## Sends the whole day to a player who just joined.
func _send_everything(peer_id: int) -> void:
	var flow := GameState.flow
	_sync.rpc_id(peer_id, "run", flow.run_dict())
	_sync.rpc_id(peer_id, "today", flow.today_dict())
	_sync.rpc_id(peer_id, "flow", flow.flow_dict())


# --- Joining players ------------------------------------------------------------------

func _on_connected_to_server() -> void:
	_hello.rpc_id(1, local_name, _version())


func _on_connection_failed() -> void:
	_end("SESSION_CANT_CONNECT")


func _on_server_disconnected() -> void:
	_end("SESSION_HOST_LEFT")


@rpc("authority", "call_remote", "reliable")
func _welcome(member: String) -> void:
	GameState.local_member = StringName(member)
	joined.emit()


@rpc("authority", "call_remote", "reliable")
func _refuse(reason: String) -> void:
	_end(reason)


@rpc("authority", "call_remote", "reliable")
func _set_names(data: Dictionary) -> void:
	names.clear()
	for member: Variant in data:
		var player_name: String = data[member]
		names[JsonValue.as_name(member)] = player_name
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _sync(channel: String, data: Dictionary) -> void:
	if mode != Mode.CLIENT:
		return
	var flow := GameState.flow
	if flow == null:
		_pending[channel] = data
		if _pending.has("run") and _pending.has("today") and _pending.has("flow"):
			GameState.adopt_copy(DayFlow.mirror(Content.catalog, _pending["run"], _pending["today"], _pending["flow"]))
			_pending.clear()
		return
	match channel:
		"run":
			flow.apply_run(data)
			EventBus.cash_changed.emit(flow.controller.run.cash)
		"today":
			flow.apply_today(data)
		"flow":
			flow.apply_flow(data)


@rpc("authority", "call_remote", "reliable")
func _auction_events(events: Array) -> void:
	var typed: Array[Dictionary] = []
	for event: Variant in events:
		var entry: Dictionary = event
		typed.append(entry)
	EventBus.auction_events.emit(typed)


func _end(reason: String) -> void:
	last_end_reason = reason
	leave()
	GameState.end_run()
	ended.emit(reason)


func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))
