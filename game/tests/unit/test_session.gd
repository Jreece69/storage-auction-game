extends GutTest
## Playing solo needs no network: the local player is the host and the only
## crew member. (Real sessions over the network are played end to end by
## tools/coop_smoke.sh.)


func after_each() -> void:
	Session.leave()
	GameState.end_run()


func test_solo_play_is_offline_and_the_host() -> void:
	assert_false(Session.is_online())
	assert_true(Session.is_host())
	assert_false(Session.is_client())


func test_a_crewmate_without_a_name_is_called_by_their_seat() -> void:
	assert_eq(Session.name_of(&"p3"), tr("UI_PLAYER") % 3)


func test_hosting_seats_the_host_as_p1() -> void:
	assert_eq(Session.host("Jack", 47390), OK)
	assert_true(Session.is_online())
	assert_true(Session.is_host())
	assert_eq(Session.seated(), [Crew.HOST] as Array[StringName])
	assert_eq(Session.name_of(Crew.HOST), "Jack")
	assert_eq(GameState.local_member, Crew.HOST)


func test_leaving_goes_back_to_solo() -> void:
	Session.host("Jack", 47391)
	Session.leave()
	assert_false(Session.is_online())
	assert_true(Session.seated().is_empty())


func test_moves_made_solo_go_straight_to_the_day() -> void:
	GameState.new_game(3)
	assert_true(GameState.act("go_to_auction"))
	assert_eq(GameState.flow.stage, DayFlow.Stage.PEEK)
