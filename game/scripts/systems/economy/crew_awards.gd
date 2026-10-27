class_name CrewAwards
extends RefCounted
## End-of-day awards for a crew, from the day's summary: who found the best
## item, who spent most on lockers, who sold most, and who outbid their own
## crew most often. The blame and the bragging are half the fun.

## Each award: [code]{"award": id, "member": member id, "amount": int}[/code],
## in a fixed order. A tie goes to the earlier seat. Awards nobody earned
## today are left out, and a crew of one gets none.
static func for_day(summary: Dictionary) -> Array[Dictionary]:
	var awards: Array[Dictionary] = []
	var members: Dictionary = summary.get("members", {})
	var crew: Array = summary.get("crew", members.keys())
	if crew.size() < 2:
		return awards
	var finder := JsonValue.as_name(summary.get("best_find_member", ""))
	var best := JsonValue.as_int(summary.get("best_find_value", 0))
	if finder != &"" and best > 0:
		awards.append({"award": &"best_find", "member": finder, "amount": best})
	_add_top(awards, &"big_spender", members, "spent_on_lockers")
	_add_top(awards, &"silver_tongue", members, "sales")
	_add_top(awards, &"friendly_fire", members, "friendly_fire")
	return awards


## The member with the most of [param stat], if anyone has any.
static func _add_top(awards: Array[Dictionary], award: StringName, members: Dictionary, stat: String) -> void:
	var top: StringName = &""
	var most := 0
	for seat in Crew.MAX:
		var member := Crew.member_id(seat)
		if not members.has(String(member)):
			continue
		var entry: Dictionary = members[String(member)]
		var amount := JsonValue.as_int(entry.get(stat, 0))
		if amount > most:
			top = member
			most = amount
	if top != &"":
		awards.append({"award": award, "member": top, "amount": most})
