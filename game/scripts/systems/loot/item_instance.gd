class_name ItemInstance
extends RefCounted
## One actual item: which kind it is ([ItemDef]) plus what was rolled for it.
## Phase 2 adds provenance and value modifiers.

var uid: int
var def_id: StringName
## Rolled within the definition's value range, before condition.
var base_value: int
var condition: StringName
var dirty: bool


func _init(p_uid: int = 0, p_def_id: StringName = &"", p_base_value: int = 0, p_condition: StringName = &"good", p_dirty: bool = false) -> void:
	uid = p_uid
	def_id = p_def_id
	base_value = p_base_value
	condition = p_condition
	dirty = p_dirty


func to_dict() -> Dictionary:
	return {
		"uid": uid,
		"def": String(def_id),
		"base_value": base_value,
		"condition": String(condition),
		"dirty": dirty,
	}


static func from_dict(data: Dictionary) -> ItemInstance:
	var dirty_flag: bool = data.get("dirty", false)
	return ItemInstance.new(
		JsonValue.as_int(data["uid"]),
		JsonValue.as_name(data["def"]),
		JsonValue.as_int(data["base_value"]),
		JsonValue.as_name(data["condition"]),
		dirty_flag,
	)
