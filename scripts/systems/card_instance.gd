class_name CardInstance
extends RefCounted

const MIN_LEVEL := 1
const MAX_LEVEL := 3

static var _allocation_counter := 0

var instance_id: String
var card_id: String
var level: int


func _init(
		value_card_id: String = "",
		value_level: int = MIN_LEVEL,
		value_instance_id: String = ""
	) -> void:
	card_id = value_card_id.strip_edges()
	level = clampi(value_level, MIN_LEVEL, MAX_LEVEL)
	instance_id = value_instance_id.strip_edges()
	if instance_id.is_empty():
		instance_id = _allocate_instance_id()


func is_valid() -> bool:
	return (
		not instance_id.is_empty()
		and not card_id.is_empty()
		and level >= MIN_LEVEL
		and level <= MAX_LEVEL
	)


func is_fixed() -> bool:
	return false


func duplicate_instance() -> CardInstance:
	return CardInstance.new(card_id, level, instance_id)


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"card_id": card_id,
		"level": level,
	}


static func from_dict(data: Dictionary) -> CardInstance:
	var parsed_instance_id := String(data.get("instance_id", "")).strip_edges()
	var parsed_card_id := String(data.get("card_id", "")).strip_edges()
	var parsed_level := int(data.get("level", MIN_LEVEL))
	if (
		parsed_instance_id.is_empty()
		or parsed_card_id.is_empty()
		or parsed_level < MIN_LEVEL
		or parsed_level > MAX_LEVEL
	):
		return null
	return CardInstance.new(parsed_card_id, parsed_level, parsed_instance_id)


static func _allocate_instance_id() -> String:
	_allocation_counter += 1
	return "card-%016x-%06x" % [Time.get_ticks_usec(), _allocation_counter]
