class_name MemberLedger
extends RefCounted
## One crew member's day: what they won, spent and sold, and how often they
## outbid their own crew. The raw material for end-of-day awards and blame.

var member: StringName
var lockers_won: int = 0
var spent_on_lockers: int = 0
var sales: int = 0
var items_sold: int = 0
## Times they outbid a crewmate, raising what the crew paid.
var friendly_fire: int = 0


func _init(p_member: StringName = &"") -> void:
	member = p_member


func to_dict() -> Dictionary:
	return {
		"member": String(member),
		"lockers_won": lockers_won,
		"spent_on_lockers": spent_on_lockers,
		"sales": sales,
		"items_sold": items_sold,
		"friendly_fire": friendly_fire,
	}


static func from_dict(data: Dictionary) -> MemberLedger:
	var ledger := MemberLedger.new(JsonValue.as_name(data.get("member", "")))
	ledger.lockers_won = JsonValue.as_int(data.get("lockers_won", 0))
	ledger.spent_on_lockers = JsonValue.as_int(data.get("spent_on_lockers", 0))
	ledger.sales = JsonValue.as_int(data.get("sales", 0))
	ledger.items_sold = JsonValue.as_int(data.get("items_sold", 0))
	ledger.friendly_fire = JsonValue.as_int(data.get("friendly_fire", 0))
	return ledger
