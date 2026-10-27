class_name UidCounter
extends RefCounted
## Hands out item ids that are unique within one save. The run keeps one and
## saves where it got to.

var next_uid: int = 1


func next() -> int:
	var uid := next_uid
	next_uid += 1
	return uid
