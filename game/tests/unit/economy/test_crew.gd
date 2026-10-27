extends GutTest
## Crew members are named by seat, p1 (the host) to p4.


func test_ids_follow_seats() -> void:
	assert_eq(Crew.member_id(0), &"p1")
	assert_eq(Crew.member_id(3), &"p4")
	assert_eq(Crew.seat_of(&"p1"), 0)
	assert_eq(Crew.seat_of(&"p4"), 3)


func test_anything_else_has_no_seat() -> void:
	assert_eq(Crew.seat_of(&"marla"), -1)
	assert_eq(Crew.seat_of(&"p9"), -1)
	assert_eq(Crew.seat_of(&""), -1)


func test_crew_sizes_run_from_one_to_four() -> void:
	assert_eq(Crew.of_size(1), [&"p1"] as Array[StringName])
	assert_eq(Crew.of_size(3), [&"p1", &"p2", &"p3"] as Array[StringName])
	assert_eq(Crew.of_size(9).size(), Crew.MAX)
	assert_eq(Crew.of_size(0).size(), 1)
