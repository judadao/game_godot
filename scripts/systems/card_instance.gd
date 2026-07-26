class_name CardInstance
extends RefCounted

const MIN_LEVEL := 1
const MAX_LEVEL := 3

static var _next_instance_id := 1

var instance_id := 0
var card_id := ""
var level := MIN_LEVEL


func _init(
		value_card_id: String = "",
		value_level: int = MIN_LEVEL,
		value_instance_id: int = 0
	) -> void:
	card_id = value_card_id.strip_edges()
	level = clampi(value_level, MIN_LEVEL, MAX_LEVEL)
	if value_instance_id > 0:
		instance_id = value_instance_id
		_next_instance_id = maxi(_next_instance_id, instance_id + 1)
	else:
		instance_id = _next_instance_id
		_next_instance_id += 1


func is_valid() -> bool:
	return instance_id > 0 and not card_id.is_empty() and level >= MIN_LEVEL and level <= MAX_LEVEL


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"card_id": card_id,
		"level": level,
	}


static func from_dict(data: Dictionary) -> CardInstance:
	var parsed_card_id := String(data.get("card_id", "")).strip_edges()
	var parsed_instance_id := int(data.get("instance_id", 0))
	var parsed_level := int(data.get("level", MIN_LEVEL))
	if parsed_card_id.is_empty() or parsed_instance_id <= 0:
		return null
	if parsed_level < MIN_LEVEL or parsed_level > MAX_LEVEL:
		return null
	return CardInstance.new(parsed_card_id, parsed_level, parsed_instance_id)
