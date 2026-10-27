class_name AuctionYard
extends Control
## The morning at the auction yard, one locker at a time: peek through the
## door, bid against the rivals, then for a win the reveal and loading the
## van. It draws the day as DayFlow has it and sends this player's moves
## through GameState.act, so in co-op every player sees the same auction and
## bids with their own paddle.

## Lines kept in the bidding feed.
const FEED_LINES: int = 5

var _flow: DayFlow
var _member: StringName
var _seat: int
var _feed: PackedStringArray = PackedStringArray()
var _rival_labels: Dictionary[StringName, Label] = {}
var _haul_toggles: Dictionary[int, CheckBox] = {}
## What's drawn already, so panels are only rebuilt when the day moves on.
var _drawn_stage: int = -1
var _drawn_lot: int = -1

@onready var _lot_label: Label = %LotLabel
@onready var _cash_label: Label = %CashLabel
@onready var _peek_panel: Control = %PeekPanel
@onready var _peek_timer_label: Label = %PeekTimerLabel
@onready var _peek_items: VBoxContainer = %PeekItems
@onready var _hidden_label: Label = %HiddenLabel
@onready var _opens_at_label: Label = %OpensAtLabel
@onready var _start_button: Button = %StartButton
@onready var _skip_button: Button = %SkipButton
@onready var _bidding_panel: Control = %BiddingPanel
@onready var _price_label: Label = %PriceLabel
@onready var _high_bidder_label: Label = %HighBidderLabel
@onready var _call_label: Label = %CallLabel
@onready var _countdown_bar: ProgressBar = %CountdownBar
@onready var _rivals: VBoxContainer = %Rivals
@onready var _feed_label: Label = %FeedLabel
@onready var _raise_button: Button = %RaiseButton
@onready var _jump_button: Button = %JumpButton
@onready var _pass_button: Button = %PassButton
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _result_button: Button = %ResultButton
@onready var _reveal_panel: Control = %RevealPanel
@onready var _reveal_items: VBoxContainer = %RevealItems
@onready var _reveal_total_label: Label = %RevealTotalLabel
@onready var _reveal_skip_button: Button = %RevealSkipButton
@onready var _load_button: Button = %LoadButton
@onready var _haul_panel: Control = %HaulPanel
@onready var _haul_title: Label = %HaulTitle
@onready var _capacity_label: Label = %CapacityLabel
@onready var _haul_items: VBoxContainer = %HaulItems
@onready var _haul_hint_label: Label = %HaulHintLabel
@onready var _drive_button: Button = %DriveButton
@onready var _done_panel: Control = %DonePanel
@onready var _done_count_label: Label = %DoneCountLabel
@onready var _to_shop_button: Button = %ToShopButton


func _ready() -> void:
	_flow = GameState.flow
	_member = GameState.local_member
	_seat = GameState.local_seat()
	EventBus.cash_changed.connect(_show_cash)
	EventBus.flow_changed.connect(_redraw)
	EventBus.auction_events.connect(_on_auction_events)
	_start_button.pressed.connect(GameState.act.bind("ready"))
	_skip_button.pressed.connect(GameState.act.bind("sit_out"))
	_raise_button.pressed.connect(GameState.act.bind("raise"))
	_jump_button.pressed.connect(GameState.act.bind("jump"))
	_pass_button.pressed.connect(_on_pass_pressed)
	_result_button.pressed.connect(GameState.act.bind("continue"))
	_reveal_skip_button.pressed.connect(GameState.act.bind("show_all"))
	_load_button.pressed.connect(GameState.act.bind("load"))
	_drive_button.pressed.connect(GameState.act.bind("drive"))
	_to_shop_button.pressed.connect(GameState.act.bind("open_shop"))
	_redraw()


## The clocks run down between changes, so they're redrawn every frame.
func _process(_delta: float) -> void:
	if _flow.stage == DayFlow.Stage.PEEK:
		_peek_timer_label.text = tr("AUCTION_PEEK_TIMER") % ceili(_flow.peek_left)
	elif _flow.stage == DayFlow.Stage.BIDDING and _flow.auction != null:
		_countdown_bar.value = _flow.auction.countdown / _rules().countdown_seconds


## Brings the screen up to date with the day.
func _redraw() -> void:
	var stage := _flow.stage
	var lot := _flow.locker.lot_number if _flow.locker != null else 0
	var moved_on := stage != _drawn_stage or lot != _drawn_lot
	_drawn_stage = stage
	_drawn_lot = lot
	_show_cash(GameState.cash)
	match stage:
		DayFlow.Stage.PEEK:
			_draw_peek(moved_on)
		DayFlow.Stage.BIDDING:
			_draw_bidding(moved_on)
		DayFlow.Stage.RESULT:
			_draw_result(moved_on)
		DayFlow.Stage.REVEAL:
			_draw_reveal(moved_on)
		DayFlow.Stage.HAUL:
			_draw_haul(moved_on)
		DayFlow.Stage.MORNING_DONE:
			_draw_done(moved_on)


# --- Peek ------------------------------------------------------------------

func _draw_peek(moved_on: bool) -> void:
	var locker := _flow.locker
	if moved_on:
		_show_panel(_peek_panel)
		_draw_lot_title()
		UiKit.clear(_peek_items)
		for item in locker.visible_items_for(_seat):
			var rarity := _pricing().def_of(item).rarity
			var line := UiKit.label(UiKit.fmt("PEEK_ITEM", [UiKit.item_name(item.def_id), UiKit.rarity_name(rarity)]))
			line.add_theme_color_override("font_color", UiKit.rarity_color(rarity))
			_peek_items.add_child(line)
		_hidden_label.text = tr("AUCTION_HIDDEN") % locker.hidden_count_for(_seat)
		var opening := Money.format(locker.opening_price)
		if locker.opening_price > GameState.cash:
			_opens_at_label.text = tr("AUCTION_OPENS_AT_BROKE") % opening
		else:
			_opens_at_label.text = tr("AUCTION_OPENS_AT") % opening
	var answered := _flow.ready.has(_member)
	_start_button.text = _crew_vote_text("AUCTION_START", answered)
	_start_button.disabled = answered
	_skip_button.disabled = answered
	_peek_timer_label.text = tr("AUCTION_PEEK_TIMER") % ceili(_flow.peek_left)
	if moved_on:
		_start_button.grab_focus()


# --- Bidding ---------------------------------------------------------------

func _draw_bidding(moved_on: bool) -> void:
	var auction := _flow.auction
	if moved_on:
		_show_panel(_bidding_panel)
		_draw_lot_title()
		_feed.clear()
		_call_label.text = ""
		UiKit.clear(_rivals)
		_rival_labels.clear()
		for bidder in auction.bidders:
			var line := UiKit.label("")
			_rivals.add_child(line)
			_rival_labels[bidder.id] = line
		if auction.crew_out.has(_member):
			_add_feed(tr("FEED_YOU_PASS"))
	if auction.high_bidder == Auction.NOBODY:
		_price_label.text = tr("AUCTION_PRICE_OPENING") % Money.format(auction.opening_price)
		_high_bidder_label.text = tr("AUCTION_NO_BIDS")
	else:
		_price_label.text = Money.format(auction.price)
		_high_bidder_label.text = tr("AUCTION_HIGH_BIDDER") % UiKit.bidder_name(auction.high_bidder)
	_countdown_bar.value = auction.countdown / _rules().countdown_seconds
	for bidder in auction.bidders:
		var status := "AUCTION_RIVAL_OUT" if bidder.folded else "AUCTION_RIVAL_IN"
		if _rival_labels.has(bidder.id):
			_rival_labels[bidder.id].text = tr(status) % [UiKit.rival_name(bidder.id), tr(bidder.def.personality_key)]
	var raise_to := auction.next_bid()
	var jump_to := auction.jump_bid()
	_raise_button.text = tr("AUCTION_RAISE") % Money.format(raise_to)
	_raise_button.disabled = not auction.can_bid(_member, raise_to)
	_jump_button.text = tr("AUCTION_JUMP") % Money.format(jump_to)
	_jump_button.disabled = not auction.can_bid(_member, jump_to)
	_pass_button.disabled = auction.crew_out.has(_member)
	_feed_label.text = "\n".join(_feed)
	if moved_on:
		_raise_button.grab_focus()


func _on_pass_pressed() -> void:
	if GameState.act("pass"):
		_add_feed(tr("FEED_YOU_PASS"))


func _on_auction_events(events: Array[Dictionary]) -> void:
	for event in events:
		var kind: String = event["type"]
		match kind:
			"bid":
				_show_bid(event)
			"call":
				_call_label.text = tr("AUCTION_GOING_ONCE") if JsonValue.as_int(event["stage"]) == 1 else tr("AUCTION_GOING_TWICE")
				_add_feed(_call_label.text)
			"fold":
				_add_feed(tr("FEED_FOLD") % UiKit.bidder_name(JsonValue.as_name(event["bidder"])))
			"sold":
				_call_label.text = tr("AUCTION_SOLD")
			"unsold":
				_call_label.text = tr("AUCTION_UNSOLD")


func _show_bid(event: Dictionary) -> void:
	var bidder := JsonValue.as_name(event["bidder"])
	var amount := Money.format(JsonValue.as_int(event["amount"]))
	var is_jump: bool = event["jump"]
	var friendly_fire: bool = event["friendly_fire"]
	_call_label.text = ""
	if friendly_fire and bidder == _member:
		_add_feed(tr("FEED_YOU_FRIENDLY_FIRE") % amount)
	elif friendly_fire:
		_add_feed(tr("FEED_FRIENDLY_FIRE") % [UiKit.bidder_name(bidder), amount])
	elif bidder == _member:
		_add_feed((tr("FEED_YOU_JUMP") if is_jump else tr("FEED_YOU_BID")) % amount)
	else:
		_add_feed((tr("FEED_JUMP") if is_jump else tr("FEED_BID")) % [UiKit.bidder_name(bidder), amount])


func _add_feed(line: String) -> void:
	_feed.append(line)
	while _feed.size() > FEED_LINES:
		_feed.remove_at(0)
	_feed_label.text = "\n".join(_feed)


# --- Result ----------------------------------------------------------------

func _draw_result(moved_on: bool) -> void:
	if not moved_on:
		return
	_show_panel(_result_panel)
	_draw_lot_title()
	var price := Money.format(_flow.price)
	if _flow.winner == Auction.NOBODY:
		_result_label.text = tr("RESULT_UNSOLD")
	elif _flow.winner == _member:
		_result_label.text = tr("RESULT_WON") % price
	else:
		_result_label.text = tr("RESULT_LOST") % [UiKit.bidder_name(_flow.winner), price]
	_result_button.text = tr("RESULT_OPEN") if _flow.crew_won() else tr("RESULT_NEXT")
	_result_button.grab_focus()


# --- Reveal ----------------------------------------------------------------

func _draw_reveal(moved_on: bool) -> void:
	var locker := _flow.locker
	if moved_on:
		_show_panel(_reveal_panel)
		_draw_lot_title()
		UiKit.clear(_reveal_items)
		_reveal_total_label.text = ""
		_load_button.text = tr("HAUL_LOAD") % tr(_controller().vehicle().name_key)
	while _reveal_items.get_child_count() < _flow.revealed:
		var item := locker.items[_reveal_items.get_child_count()]
		var def := _pricing().def_of(item)
		var value := Money.format(_pricing().market_value(item))
		var line := UiKit.label(UiKit.fmt("REVEAL_ITEM", [UiKit.item_name(item.def_id), UiKit.state_of(item), value]))
		line.add_theme_color_override("font_color", UiKit.rarity_color(def.rarity))
		_reveal_items.add_child(line)
	var all_out := _flow.revealed >= locker.items.size()
	_load_button.disabled = not all_out
	_reveal_skip_button.disabled = all_out
	if all_out and _reveal_total_label.text.is_empty():
		var total := Money.format(_pricing().locker_value(locker))
		_reveal_total_label.text = tr("REVEAL_TOTAL") % [total, Money.format(_flow.price)]
		_load_button.grab_focus()
	elif moved_on:
		_reveal_skip_button.grab_focus()


# --- Haul ------------------------------------------------------------------

func _draw_haul(moved_on: bool) -> void:
	var plan := _flow.haul
	if moved_on:
		_show_panel(_haul_panel)
		_draw_lot_title()
		_haul_title.text = tr("HAUL_TITLE") % tr(_controller().vehicle().name_key)
		_haul_hint_label.text = tr("HAUL_HINT")
		UiKit.clear(_haul_items)
		_haul_toggles.clear()
		for item in _flow.locker.items:
			var toggle := CheckBox.new()
			toggle.text = _haul_line(item)
			toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			toggle.custom_minimum_size = Vector2(0, UiKit.ROW_HEIGHT)
			toggle.toggled.connect(_on_haul_toggled.bind(item.uid))
			_haul_items.add_child(toggle)
			_haul_toggles[item.uid] = toggle
	for uid: int in _haul_toggles:
		_haul_toggles[uid].set_pressed_no_signal(plan.is_selected(uid))
	var vehicle := _controller().vehicle()
	var capacity := tr("HAUL_CAPACITY") % [plan.weight_used(), vehicle.max_weight, plan.volume_used(), vehicle.max_volume]
	var scrap := tr("HAUL_SCRAP") % Money.format(plan.scrap_value(_flow.locker.junk_weight))
	_capacity_label.text = capacity + "\n" + scrap
	var answered := _flow.ready.has(_member)
	_drive_button.text = _crew_vote_text("HAUL_DRIVE", answered)
	_drive_button.disabled = answered
	if moved_on:
		_drive_button.grab_focus()


## Clicks the row for item [param uid], loading or unloading it. Returns
## whether the click took (loading fails when the item won't fit).
func click_haul_row(uid: int) -> bool:
	var was_loaded := _flow.haul.is_selected(uid)
	var toggle := _haul_toggles[uid]
	toggle.button_pressed = not toggle.button_pressed
	return _flow.haul.is_selected(uid) != was_loaded


func _on_haul_toggled(toggled_on: bool, uid: int) -> void:
	var plan := _flow.haul
	if toggled_on == plan.is_selected(uid):
		return
	# Checked here first, so a full van says so at once, even in co-op.
	if toggled_on and not plan.fits(_flow.locker.find_item(uid)):
		_haul_toggles[uid].set_pressed_no_signal(false)
		_haul_hint_label.text = tr("HAUL_NO_FIT")
		return
	_haul_hint_label.text = tr("HAUL_HINT")
	GameState.act("toggle", {"uid": uid})


func _haul_line(item: ItemInstance) -> String:
	var def := _pricing().def_of(item)
	var value := Money.format(_pricing().market_value(item))
	return UiKit.fmt("HAUL_ITEM", [UiKit.item_name(item.def_id), UiKit.state_of(item), value, def.weight, def.size])


# --- Done ------------------------------------------------------------------

func _draw_done(moved_on: bool) -> void:
	if not moved_on:
		return
	_show_panel(_done_panel)
	_lot_label.text = tr("AUCTION_MORNING_TITLE")
	var today := _controller().today
	_done_count_label.text = tr("AUCTION_MORNING_COUNT") % [today.ledger.lockers_won, today.lockers.size()]
	_to_shop_button.grab_focus()


# --- Shared ----------------------------------------------------------------

func _draw_lot_title() -> void:
	var locker := _flow.locker
	var theme: LockerThemeDef = _controller().catalog.themes[locker.theme_id]
	_lot_label.text = tr("AUCTION_LOT") % [locker.lot_number, _controller().today.lockers.size(), tr(theme.name_key)]


## The text for a button that waits on the whole crew: plain when playing
## alone, with a count of who's ready in co-op.
func _crew_vote_text(key: String, answered: bool) -> String:
	var crew_size := _flow.crew().size()
	if crew_size <= 1:
		return tr(key)
	if answered:
		return tr("UI_WAITING_FOR_CREW") % [_flow.ready.size(), crew_size]
	return tr("UI_CREW_READY") % [tr(key), _flow.ready.size(), crew_size]


func _show_panel(panel: Control) -> void:
	var panels: Array[Control] = [_peek_panel, _bidding_panel, _result_panel, _reveal_panel, _haul_panel, _done_panel]
	for each in panels:
		each.visible = each == panel


func _show_cash(cash: int) -> void:
	_cash_label.text = tr("UI_CASH") % Money.format(cash)


func _controller() -> RunController:
	return _flow.controller


func _pricing() -> Pricing:
	return _flow.controller.pricing


func _rules() -> AuctionRules:
	return _flow.controller.catalog.economy.auction
