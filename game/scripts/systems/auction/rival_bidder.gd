class_name RivalBidder
extends RefCounted
## One rival at one auction: their private estimate, how high they'll go, and
## when they'll next answer the high bid.

var def: RivalDef
## Their private guess at the locker's value.
var estimate: int = 0
## The most they'll bid here. Never above what's left of their budget.
var max_bid: int = 0
## Dropped out of this auction.
var folded: bool = false
## Seconds until they answer the current high bid. Negative when not waiting.
var timer: float = -1.0

var id: StringName:
	get:
		return def.id


func _init(p_def: RivalDef, p_max_bid: int = 0) -> void:
	def = p_def
	max_bid = p_max_bid
