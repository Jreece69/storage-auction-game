class_name Customer
extends RefCounted
## One shopper haggling over one item. They have a private limit. Their first
## offer comes in under it; each time the player counters too high they edge
## closer to it, until they agree or run out of patience and leave.

enum State { OFFERING, SOLD, LEFT }
## Why a customer left without buying.
enum Reason { NONE, BROWSING, TOO_PRICEY, DECLINED, LOST_PATIENCE }

var def: CustomerDef
var item_uid: int
## The price tag when they picked the item up.
var tag: int
## The most they'll pay. Hidden from the player.
var limit: int
var offer: int = 0
var patience_left: int
var state: State = State.OFFERING
var reason: Reason = Reason.NONE

var _step: int


func _init(p_def: CustomerDef, p_item_uid: int, p_tag: int, p_limit: int, p_offer: int, price_step: int) -> void:
	def = p_def
	item_uid = p_item_uid
	tag = p_tag
	limit = p_limit
	offer = p_offer
	patience_left = p_def.patience
	_step = price_step


## A customer picks up an item tagged [param tag] that's worth
## [param market_value]. They might only be browsing, or balk at the tag;
## otherwise they make an opening offer below their limit.
static func approach(p_def: CustomerDef, uid: int, p_tag: int, market_value: int, price_step: int, rng: RandomNumberGenerator) -> Customer:
	var p_limit := maxi(1, roundi(market_value * rng.randf_range(p_def.pay_min, p_def.pay_max)))
	var customer := Customer.new(p_def, uid, p_tag, p_limit, 0, price_step)
	if rng.randf() >= p_def.interest_chance:
		customer._leave(Reason.BROWSING)
	elif p_tag > p_limit * p_def.walk_away_ratio:
		customer._leave(Reason.TOO_PRICEY)
	else:
		var opening := Money.round_nice(mini(p_tag, p_limit) * rng.randf_range(p_def.offer_min, p_def.offer_max))
		customer.offer = clampi(opening, 1, mini(p_tag, p_limit))
	return customer


func is_offering() -> bool:
	return state == State.OFFERING


## The player takes the offer. Returns the sale price.
func accept() -> int:
	state = State.SOLD
	return offer


## The player names a price. They take anything up to their limit; above it
## they edge their offer up, or leave once their patience is gone.
## Returns "accept", "raise" or "leave".
func counter(amount: int) -> String:
	if not is_offering():
		return "leave"
	if amount <= limit:
		offer = amount
		state = State.SOLD
		return "accept"
	if patience_left <= 0:
		_leave(Reason.LOST_PATIENCE)
		return "leave"
	patience_left -= 1
	var raised := offer + Money.round_nice((limit - offer) * def.raise_share)
	offer = clampi(maxi(raised, offer + _step), offer, limit)
	return "raise"


## The player turns them down.
func decline() -> void:
	_leave(Reason.DECLINED)


## The customer as plain data, for other players' screens. Their limit
## stays on the host unless [param secrets] is set.
func to_dict(secrets: bool = false) -> Dictionary:
	var data := {
		"def": String(def.id),
		"item": item_uid,
		"tag": tag,
		"offer": offer,
		"patience_left": patience_left,
		"state": state,
		"reason": reason,
	}
	if secrets:
		data["limit"] = limit
	return data


static func from_dict(data: Dictionary, catalog: Catalog, price_step: int) -> Customer:
	var copy := Customer.new(catalog.customers[JsonValue.as_name(data["def"])], JsonValue.as_int(data["item"]), JsonValue.as_int(data["tag"]), JsonValue.as_int(data.get("limit", 0)), JsonValue.as_int(data["offer"]), price_step)
	copy.patience_left = JsonValue.as_int(data.get("patience_left", 0))
	copy.state = JsonValue.as_int(data.get("state", State.OFFERING)) as State
	copy.reason = JsonValue.as_int(data.get("reason", Reason.NONE)) as Reason
	return copy


func _leave(why: Reason) -> void:
	state = State.LEFT
	reason = why
