extends GutTest
## End-of-day crew awards go to whoever earned them, ties to the earlier
## seat, and a solo day has none.


func test_a_solo_day_has_no_awards() -> void:
	var ledger := DayLedger.new()
	ledger.member(&"p1").sales = 100
	var summary := ledger.to_dict()
	summary["crew"] = ["p1"]
	assert_eq(CrewAwards.for_day(summary).size(), 0)


func test_a_crewmate_who_did_nothing_still_makes_it_a_crew() -> void:
	var ledger := DayLedger.new()
	ledger.member(&"p2").sales = 30
	var summary := ledger.to_dict()
	summary["crew"] = ["p1", "p2"]
	assert_eq(CrewAwards.for_day(summary).size(), 1)


func test_each_award_goes_to_whoever_earned_it() -> void:
	var ledger := DayLedger.new()
	ledger.note_find(&"robot", 900, &"p2")
	ledger.member(&"p1").spent_on_lockers = 300
	ledger.member(&"p2").spent_on_lockers = 120
	ledger.member(&"p1").sales = 40
	ledger.member(&"p3").sales = 95
	ledger.member(&"p2").friendly_fire = 2
	var awards := CrewAwards.for_day(_through_json(ledger.to_dict()))
	assert_eq(awards, [
		{"award": &"best_find", "member": &"p2", "amount": 900},
		{"award": &"big_spender", "member": &"p1", "amount": 300},
		{"award": &"silver_tongue", "member": &"p3", "amount": 95},
		{"award": &"friendly_fire", "member": &"p2", "amount": 2},
	] as Array[Dictionary])


func test_nobody_gets_an_award_for_nothing() -> void:
	var ledger := DayLedger.new()
	ledger.member(&"p1")
	ledger.member(&"p2")
	assert_eq(CrewAwards.for_day(ledger.to_dict()).size(), 0)


func test_a_tie_goes_to_the_earlier_seat() -> void:
	var ledger := DayLedger.new()
	ledger.member(&"p3").sales = 50
	ledger.member(&"p2").sales = 50
	var winner: StringName = CrewAwards.for_day(ledger.to_dict())[0]["member"]
	assert_eq(winner, &"p2")


func _through_json(data: Dictionary) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	return parsed
