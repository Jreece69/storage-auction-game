class_name Crew
extends RefCounted
## The players running the business together: one to four of them, sharing
## one bank account. Members are named by seat, p1 (the host) to p4. Solo
## play is a crew of one.
##
## Wins, sales and blunders are still credited to whoever made them, so the
## end of the day can hand out awards (and blame).

const MAX: int = 4
const HOST: StringName = &"p1"


static func member_id(seat: int) -> StringName:
	return StringName("p%d" % (seat + 1))


## The seat of [param member] (p1 is seat 0), or -1 if it isn't a member id.
static func seat_of(member: StringName) -> int:
	var text := String(member)
	if not text.begins_with("p"):
		return -1
	var seat := text.substr(1).to_int() - 1
	return seat if seat >= 0 and seat < MAX else -1


## The member ids for a crew of [param size], in seat order.
static func of_size(size: int) -> Array[StringName]:
	var members: Array[StringName] = []
	for seat in clampi(size, 1, MAX):
		members.append(member_id(seat))
	return members
