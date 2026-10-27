class_name Lobby
extends Control
## Play with friends: pick a name, then host a game or join a friend's by
## their address. The host sees who's in and starts a new game or carries on
## their saved one; everyone else waits, then the day starts on every screen
## at once (the app shell follows the day).

@onready var _name_edit: LineEdit = %NameEdit
@onready var _choice_panel: Control = %ChoicePanel
@onready var _host_button: Button = %HostButton
@onready var _address_edit: LineEdit = %AddressEdit
@onready var _join_button: Button = %JoinButton
@onready var _room_panel: Control = %RoomPanel
@onready var _status_label: Label = %StatusLabel
@onready var _crew_list: VBoxContainer = %CrewList
@onready var _start_row: Control = %StartRow
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _message_label: Label = %MessageLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_name_edit.placeholder_text = tr("LOBBY_NAME_HINT")
	_name_edit.text = Settings.player_name
	_address_edit.placeholder_text = tr("LOBBY_ADDRESS_HINT")
	_address_edit.text = Settings.last_address
	_host_button.pressed.connect(host)
	_join_button.pressed.connect(join)
	_address_edit.text_submitted.connect(_on_address_submitted)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	Session.roster_changed.connect(_draw_room)
	Session.joined.connect(_on_joined)
	Session.ended.connect(_on_ended)
	_show_choices()
	if Session.is_online():
		_show_room()
	if _name_edit.text.is_empty():
		_name_edit.grab_focus()
	else:
		_host_button.grab_focus()


## Opens a game for friends to join.
func host() -> void:
	if not _remember_name():
		return
	var err := Session.host(Settings.player_name)
	if err != OK:
		_message_label.text = tr("LOBBY_CANT_HOST") % Session.DEFAULT_PORT
		return
	_show_room()


## Joins the friend at the address typed in.
func join() -> void:
	if not _remember_name():
		return
	var address := _address_edit.text.strip_edges()
	if address.is_empty():
		_message_label.text = tr("LOBBY_NEED_ADDRESS")
		_address_edit.grab_focus()
		return
	Settings.last_address = address
	Settings.save_settings()
	var err := Session.join(Settings.player_name, address)
	if err != OK:
		_message_label.text = tr("SESSION_CANT_CONNECT")
		return
	_show_room()
	_status_label.text = tr("LOBBY_CONNECTING") % address


func _on_address_submitted(_text: String) -> void:
	join()


func _remember_name() -> bool:
	var player_name := _name_edit.text.strip_edges()
	if player_name.is_empty():
		_message_label.text = tr("LOBBY_NEED_NAME")
		_name_edit.grab_focus()
		return false
	Settings.player_name = player_name
	Settings.save_settings()
	return true


func _show_choices() -> void:
	_choice_panel.visible = true
	_room_panel.visible = false
	_name_edit.editable = true


func _show_room() -> void:
	_choice_panel.visible = false
	_room_panel.visible = true
	_name_edit.editable = false
	_message_label.text = ""
	_draw_room()
	if Session.is_host():
		_new_game_button.grab_focus()
	else:
		_back_button.grab_focus()


func _draw_room() -> void:
	if not _room_panel.visible:
		return
	var hosting := Session.mode == Session.Mode.HOST
	_start_row.visible = hosting
	_continue_button.visible = hosting and SaveManager.has_slot(SaveManager.AUTOSAVE)
	if hosting:
		_status_label.text = tr("LOBBY_HOSTING") % [", ".join(_addresses()), Session.DEFAULT_PORT]
	elif not Session.seated().is_empty():
		_status_label.text = tr("LOBBY_JOINED")
	UiKit.clear(_crew_list)
	for member in Session.seated():
		var line := tr("LOBBY_CREW_MEMBER") % [Crew.seat_of(member) + 1, Session.name_of(member)]
		if member == GameState.local_member:
			line += " " + tr("LOBBY_YOU")
		_crew_list.add_child(UiKit.label(line))


## This machine's addresses on its networks, for friends to type in.
func _addresses() -> PackedStringArray:
	var found := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	if found.is_empty():
		found.append("127.0.0.1")
	return found


func _on_joined() -> void:
	_draw_room()


func _on_ended(reason: String) -> void:
	_show_choices()
	_message_label.text = tr(reason)
	_host_button.grab_focus()


func _on_new_game_pressed() -> void:
	var entropy := RandomNumberGenerator.new()
	entropy.randomize()
	GameState.new_game(entropy.randi())


func _on_continue_pressed() -> void:
	SaveManager.load_game(SaveManager.AUTOSAVE)


func _on_back_pressed() -> void:
	Session.leave()
	Screens.go(Screens.TITLE)
