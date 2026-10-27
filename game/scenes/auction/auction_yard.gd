class_name AuctionYard
extends Control
## The morning at the auction yard, one locker at a time: peek through the
## door, bid against the rivals, then for a win the reveal and loading the
## van. The rules live in RunController and Auction; this screen shows what
## they report and passes on the player's moves as the local crew member.
##
## The auction is drawn from the events it reports (bids, calls, folds, the
## hammer), so in co-op the same screen can draw events the host broadcasts.

enum Stage { PEEK, BIDDING, RESULT, REVEAL, HAUL, DONE }

## Once the whole crew has passed, the rivals settle it this much faster.
const FAST_FORWARD: float = 4.0
## Seconds between items coming out during the reveal.
const REVEAL_INTERVAL: float = 0.45
## Lines kept in the bidding feed.
const FEED_LINES: int = 5

## Where the screen is in the current locker. Read by tests.
var stage: Stage = Stage.PEEK

var _controller: RunController
var _member: StringName
var _seat: int
var _locker: Locker = null
var _auction: Auction = null
var _plan: HaulPlan = null
var _peek_left: float = 0.0
var _feed: PackedStringArray = PackedStringArray()
var _rival_labels: Dictionary[StringName, Label] = {}
var _haul_toggles: Dictionary[int, CheckBox] = {}
var _revealed: int = 0
var _reveal_wait: float = 0.0
var _settled_winner: StringName = Auction.NOBODY
var _settled_price: int = 0

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
	_controller = GameState.controller
	_member = GameState.local_member
	_seat = GameState.local_seat()
	EventBus.cash_changed.connect(_show_cash)
	EventBus.locker_settled.connect(_on_locker_settled)
	_start_button.pressed.connect(start_bidding)
	_skip_button.pressed.connect(_on_skip_pressed)
	_raise_button.pressed.connect(_on_raise_pressed)
	_jump_button.pressed.connect(_on_jump_pressed)
	_pass_button.pressed.connect(_on_pass_pressed)
	_result_button.pressed.connect(_on_result_pressed)
	_reveal_skip_button.pressed.connect(reveal_all)
	_load_button.pressed.connect(_start_haul)
	_drive_button.pressed.connect(_on_drive_pressed)
	_to_shop_button.pressed.connect(_on_to_shop_pressed)
	_show_cash(_controller.run.cash)
	if _controller.start_day().phase == DayPlan.Phase.MORNING:
		_next_locker()
	else:
		_show_done()


func _process(delta: float) -> void:
	tick(delta)


## Runs [param seconds] of screen time: the peek clock, the auction or the
## reveal. Tests call it directly instead of waiting.
func tick(seconds: float) -> void:
	match stage:
		Stage.PEEK:
			_peek_left -= seconds
			if _peek_left <= 0.0:
				start_bidding()
			else:
				_show_peek_clock()
		Stage.BIDDING:
			var speed := FAST_FORWARD if _auction.all_crew_out() else 1.0
			_apply(_auction.advance(seconds * speed))
		Stage.REVEAL:
			_reveal_wait -= seconds
			while stage == Stage.REVEAL and _reveal_wait <= 0.0 and _revealed < _locker.items.size():
				_reveal_next()
				_reveal_wait += REVEAL_INTERVAL


## The auction in progress, or null outside the bidding. Read by tests.
func current_auction() -> Auction:
	return _auction


# --- Peek ------------------------------------------------------------------

func _next_locker() -> void:
	_locker = _controller.today.next_locker()
	if _locker == null:
		_show_done()
		return
	_auction = null
	_plan = null
	stage = Stage.PEEK
	_show_panel(_peek_panel)
	var theme: LockerThemeDef = _controller.catalog.themes[_locker.theme_id]
	_lot_label.text = tr("AUCTION_LOT") % [_locker.lot_number, _controller.today.lockers.size(), tr(theme.name_key)]
	UiKit.clear(_peek_items)
	for item in _locker.visible_items_for(_seat):
		var rarity := _controller.pricing.def_of(item).rarity
		var line := UiKit.label(UiKit.fmt("PEEK_ITEM", [UiKit.item_name(item.def_id), UiKit.rarity_name(rarity)]))
		line.add_theme_color_override("font_color", UiKit.rarity_color(rarity))
		_peek_items.add_child(line)
	_hidden_label.text = tr("AUCTION_HIDDEN") % _locker.hidden_count_for(_seat)
	var opening := Money.format(_locker.opening_price)
	if _locker.opening_price > _controller.run.cash:
		_opens_at_label.text = tr("AUCTION_OPENS_AT_BROKE") % opening
	else:
		_opens_at_label.text = tr("AUCTION_OPENS_AT") % opening
	_peek_left = _rules().peek_seconds
	_show_peek_clock()
	_start_button.grab_focus()


func _show_peek_clock() -> void:
	_peek_timer_label.text = tr("AUCTION_PEEK_TIMER") % ceili(_peek_left)


func _on_skip_pressed() -> void:
	_controller.skip_locker(_locker)
	_show_result()


# --- Bidding ---------------------------------------------------------------

## Ends the peek and opens the bidding.
func start_bidding() -> void:
	if stage != Stage.PEEK:
		return
	_auction = _controller.open_auction(_locker)
	stage = Stage.BIDDING
	_feed.clear()
	_call_label.text = ""
	_show_panel(_bidding_panel)
	UiKit.clear(_rivals)
	_rival_labels.clear()
	for bidder in _auction.bidders:
		var line := UiKit.label("")
		_rivals.add_child(line)
		_rival_labels[bidder.id] = line
	_refresh_bidding()
	_raise_button.grab_focus()


func _on_raise_pressed() -> void:
	if stage == Stage.BIDDING:
		_apply(_auction.raise(_member))


func _on_jump_pressed() -> void:
	if stage == Stage.BIDDING:
		_apply(_auction.jump(_member))


func _on_pass_pressed() -> void:
	if stage != Stage.BIDDING or _auction.crew_out.has(_member):
		return
	_auction.pass_out(_member)
	_add_feed(tr("FEED_YOU_PASS"))
	_refresh_bidding()


## Shows what the auction reported, and settles the locker once the hammer
## falls.
func _apply(events: Array[Dictionary]) -> void:
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
	if _auction.is_open():
		_refresh_bidding()
	else:
		_controller.settle_auction(_locker, _auction)
		_show_result()


func _show_bid(event: Dictionary) -> void:
	var bidder := JsonValue.as_name(event["bidder"])
	var amount := Money.format(JsonValue.as_int(event["amount"]))
	var is_jump: bool = event["jump"]
	var friendly_fire: bool = event["friendly_fire"]
	_call_label.text = ""
	if friendly_fire:
		_add_feed(tr("FEED_FRIENDLY_FIRE") % [UiKit.bidder_name(bidder), amount])
	elif bidder == _member:
		_add_feed((tr("FEED_YOU_JUMP") if is_jump else tr("FEED_YOU_BID")) % amount)
	else:
		_add_feed((tr("FEED_JUMP") if is_jump else tr("FEED_BID")) % [UiKit.bidder_name(bidder), amount])


func _refresh_bidding() -> void:
	if _auction.high_bidder == Auction.NOBODY:
		_price_label.text = tr("AUCTION_PRICE_OPENING") % Money.format(_auction.opening_price)
		_high_bidder_label.text = tr("AUCTION_NO_BIDS")
	else:
		_price_label.text = Money.format(_auction.price)
		_high_bidder_label.text = tr("AUCTION_HIGH_BIDDER") % UiKit.bidder_name(_auction.high_bidder)
	_countdown_bar.value = _auction.countdown / _rules().countdown_seconds
	for bidder in _auction.bidders:
		var status := "AUCTION_RIVAL_OUT" if bidder.folded else "AUCTION_RIVAL_IN"
		_rival_labels[bidder.id].text = tr(status) % [UiKit.rival_name(bidder.id), tr(bidder.def.personality_key)]
	var raise_to := _auction.next_bid()
	var jump_to := _auction.jump_bid()
	_raise_button.text = tr("AUCTION_RAISE") % Money.format(raise_to)
	_raise_button.disabled = not _auction.can_bid(_member, raise_to)
	_jump_button.text = tr("AUCTION_JUMP") % Money.format(jump_to)
	_jump_button.disabled = not _auction.can_bid(_member, jump_to)
	_pass_button.disabled = _auction.crew_out.has(_member)
	_feed_label.text = "\n".join(_feed)


func _add_feed(line: String) -> void:
	_feed.append(line)
	while _feed.size() > FEED_LINES:
		_feed.remove_at(0)
	_feed_label.text = "\n".join(_feed)


# --- Result ----------------------------------------------------------------

func _on_locker_settled(lot_number: int, winner: StringName, price: int) -> void:
	if _locker != null and lot_number == _locker.lot_number:
		_settled_winner = winner
		_settled_price = price


func _crew_won() -> bool:
	return _controller.crew.has(_settled_winner)


func _show_result() -> void:
	stage = Stage.RESULT
	_show_panel(_result_panel)
	var price := Money.format(_settled_price)
	if _settled_winner == Auction.NOBODY:
		_result_label.text = tr("RESULT_UNSOLD")
	elif _settled_winner == _member:
		_result_label.text = tr("RESULT_WON") % price
	else:
		_result_label.text = tr("RESULT_LOST") % [UiKit.bidder_name(_settled_winner), price]
	_result_button.text = tr("RESULT_OPEN") if _crew_won() else tr("RESULT_NEXT")
	_result_button.grab_focus()


func _on_result_pressed() -> void:
	if _crew_won():
		_start_reveal()
	else:
		_next_locker()


# --- Reveal ----------------------------------------------------------------

func _start_reveal() -> void:
	stage = Stage.REVEAL
	_show_panel(_reveal_panel)
	UiKit.clear(_reveal_items)
	_revealed = 0
	_reveal_wait = REVEAL_INTERVAL
	_reveal_total_label.text = ""
	_load_button.text = tr("HAUL_LOAD") % tr(_controller.vehicle().name_key)
	_load_button.disabled = true
	_reveal_skip_button.disabled = false
	_reveal_skip_button.grab_focus()


## Brings everything out at once.
func reveal_all() -> void:
	while stage == Stage.REVEAL and _revealed < _locker.items.size():
		_reveal_next()


func _reveal_next() -> void:
	var item := _locker.items[_revealed]
	_revealed += 1
	var def := _controller.pricing.def_of(item)
	var value := Money.format(_controller.pricing.market_value(item))
	var line := UiKit.label(UiKit.fmt("REVEAL_ITEM", [UiKit.item_name(item.def_id), UiKit.state_of(item), value]))
	line.add_theme_color_override("font_color", UiKit.rarity_color(def.rarity))
	_reveal_items.add_child(line)
	if _revealed >= _locker.items.size():
		var total := Money.format(_controller.pricing.locker_value(_locker))
		_reveal_total_label.text = tr("REVEAL_TOTAL") % [total, Money.format(_settled_price)]
		_load_button.disabled = false
		_reveal_skip_button.disabled = true
		_load_button.grab_focus()


# --- Haul ------------------------------------------------------------------

func _start_haul() -> void:
	stage = Stage.HAUL
	_plan = _controller.plan_haul(_locker)
	_show_panel(_haul_panel)
	_haul_title.text = tr("HAUL_TITLE") % tr(_controller.vehicle().name_key)
	_haul_hint_label.text = tr("HAUL_HINT")
	UiKit.clear(_haul_items)
	_haul_toggles.clear()
	for item in _locker.items:
		var toggle := CheckBox.new()
		toggle.text = _haul_line(item)
		toggle.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		toggle.custom_minimum_size = Vector2(0, UiKit.ROW_HEIGHT)
		toggle.button_pressed = _plan.is_selected(item.uid)
		toggle.toggled.connect(_on_haul_toggled.bind(item.uid, toggle))
		_haul_items.add_child(toggle)
		_haul_toggles[item.uid] = toggle
	_refresh_haul()
	_drive_button.grab_focus()


## Clicks the row for item [param uid], loading or unloading it. Returns
## whether the click took (loading fails when the item won't fit).
func click_haul_row(uid: int) -> bool:
	var was_loaded := _plan.is_selected(uid)
	var toggle := _haul_toggles[uid]
	toggle.button_pressed = not toggle.button_pressed
	return _plan.is_selected(uid) != was_loaded


func haul_plan() -> HaulPlan:
	return _plan


func _on_haul_toggled(toggled_on: bool, uid: int, toggle: CheckBox) -> void:
	if toggled_on == _plan.is_selected(uid):
		return
	if not _plan.toggle(uid):
		toggle.set_pressed_no_signal(false)
		_haul_hint_label.text = tr("HAUL_NO_FIT")
		return
	_haul_hint_label.text = tr("HAUL_HINT")
	_refresh_haul()


func _refresh_haul() -> void:
	var vehicle := _controller.vehicle()
	var capacity := tr("HAUL_CAPACITY") % [_plan.weight_used(), vehicle.max_weight, _plan.volume_used(), vehicle.max_volume]
	var scrap := tr("HAUL_SCRAP") % Money.format(_plan.scrap_value(_locker.junk_weight))
	_capacity_label.text = capacity + "\n" + scrap


func _haul_line(item: ItemInstance) -> String:
	var def := _controller.pricing.def_of(item)
	var value := Money.format(_controller.pricing.market_value(item))
	return UiKit.fmt("HAUL_ITEM", [UiKit.item_name(item.def_id), UiKit.state_of(item), value, def.weight, def.size])


func _on_drive_pressed() -> void:
	_controller.finish_haul(_locker, _plan)
	_next_locker()


# --- Done ------------------------------------------------------------------

func _show_done() -> void:
	stage = Stage.DONE
	_locker = null
	_auction = null
	_show_panel(_done_panel)
	_lot_label.text = tr("AUCTION_MORNING_TITLE")
	var today := _controller.today
	_done_count_label.text = tr("AUCTION_MORNING_COUNT") % [today.ledger.lockers_won, today.lockers.size()]
	_to_shop_button.grab_focus()


func _on_to_shop_pressed() -> void:
	_controller.start_afternoon()
	Screens.go(Screens.SHOP)


# --- Shared ----------------------------------------------------------------

func _show_panel(panel: Control) -> void:
	var panels: Array[Control] = [_peek_panel, _bidding_panel, _result_panel, _reveal_panel, _haul_panel, _done_panel]
	for each in panels:
		each.visible = each == panel


func _show_cash(cash: int) -> void:
	_cash_label.text = tr("UI_CASH") % Money.format(cash)


func _rules() -> AuctionRules:
	return _controller.catalog.economy.auction
