class_name AutumnGuardian
extends "res://scripts/monsters/enemy_base.gd"

signal phase_changed(phase: int)
signal drop_emitted(item_id: StringName, amount: int, world_position: Vector2)

const GUARDIAN_ARCHETYPE_DATA := preload("res://scripts/monsters/enemy_archetype.gd")
const PHASE_PATTERNS := {
	1: [&"root_sweep"],
	2: [&"root_sweep", &"falling_acorns"],
	3: [&"root_sweep", &"falling_acorns", &"ember_burst"],
}

@export var drop_id: StringName = &"autumn_core"
@export var drop_amount: int = 1

var _guardian_pattern_index := 0
var _drop_emitted := false


func _ready() -> void:
	apply_archetype(_build_guardian_archetype())
	phase = 1
	super._ready()


func get_phase_patterns(requested_phase: int) -> Array:
	return (PHASE_PATTERNS.get(clampi(requested_phase, 1, 3), []) as Array).duplicate()


func get_pattern_profile(pattern: StringName) -> Dictionary:
	match pattern:
		&"falling_acorns":
			return {"kind": "falling_hazard", "range": 285.0, "damage": 20, "hazards": 3}
		&"ember_burst":
			return {"kind": "radial_burst", "range": 230.0, "damage": 32, "hazards": 1}
		_:
			return {"kind": "melee_arc", "range": 150.0, "damage": 24, "hazards": 1}


func perform_next_attack() -> StringName:
	var patterns := get_phase_patterns(phase)
	if patterns.is_empty():
		return &""
	var pattern := patterns[_guardian_pattern_index % patterns.size()] as StringName
	_guardian_pattern_index += 1
	attack_telegraphed.emit(pattern, _telegraph_duration())
	return pattern


func _apply_attack_pattern(pattern: StringName) -> void:
	if target == null or not is_instance_valid(target):
		return
	var profile := get_pattern_profile(pattern)
	_spawn_pattern_visual(String(profile["kind"]), target.global_position)
	if global_position.distance_to(target.global_position) <= float(profile["range"]) and target.has_method("take_hit"):
		target.call("take_hit", int(profile["damage"]), global_position, 280.0 if pattern == &"ember_burst" else 180.0)


func _spawn_pattern_visual(kind: String, target_position: Vector2) -> void:
	var effect := Polygon2D.new()
	effect.z_index = 8
	if kind == "falling_hazard":
		effect.polygon = PackedVector2Array([
			Vector2(-90, -210), Vector2(-66, 0), Vector2(-114, 0),
			Vector2(0, -250), Vector2(24, 0), Vector2(-24, 0),
			Vector2(90, -210), Vector2(114, 0), Vector2(66, 0),
		])
		effect.global_position = target_position
		effect.color = Color(0.96, 0.58, 0.18, 0.72)
	elif kind == "radial_burst":
		var points := PackedVector2Array()
		for index in 16:
			var angle := TAU * float(index) / 16.0
			var radius := 210.0 if index % 2 == 0 else 128.0
			points.append(Vector2.from_angle(angle) * radius)
		effect.polygon = points
		effect.global_position = global_position
		effect.color = Color(1.0, 0.22, 0.06, 0.58)
	else:
		effect.polygon = PackedVector2Array([
			Vector2(0, -25), Vector2(155, -8), Vector2(150, 28), Vector2(0, 12),
		])
		effect.global_position = global_position
		effect.color = Color(0.82, 0.38, 0.12, 0.64)
	get_parent().add_child(effect)
	var tween := effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.28)
	tween.tween_callback(effect.queue_free)


func _after_damage() -> void:
	if archetype == null:
		return
	var ratio := float(health) / float(maxi(1, int(archetype.get("max_health"))))
	var next_phase := 1
	if ratio <= 0.33:
		next_phase = 3
	elif ratio <= 0.66:
		next_phase = 2
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)


func _before_defeated() -> void:
	if _drop_emitted:
		return
	_drop_emitted = true
	drop_emitted.emit(drop_id, maxi(1, drop_amount), global_position)


func _telegraph_duration() -> float:
	match phase:
		2:
			return 0.65
		3:
			return 0.5
		_:
			return 0.85


func _get_attack_telegraph_time() -> float:
	return _telegraph_duration()


func _build_guardian_archetype() -> Resource:
	var result := GUARDIAN_ARCHETYPE_DATA.new()
	result.set("archetype_id", &"guardian")
	result.set("display_name", "Heartwood Guardian")
	result.set("behavior", &"guardian")
	result.set("max_health", 600)
	result.set("attack_damage", 24)
	result.set("defense", 6)
	result.set("speed", 68.0)
	result.set("detection_range", 620.0)
	result.set("attack_range", 145.0)
	result.set("attack_cooldown", 1.35)
	result.set("telegraph_time", 0.85)
	result.set("experience_reward", 300)
	result.set("gold_reward", 120)
	result.set("attack_patterns", [&"root_sweep", &"falling_acorns", &"ember_burst"])
	result.set("visual_color", Color(0.46, 0.16, 0.07, 1.0))
	result.set("visual_scale", Vector2(1.7, 1.7))
	return result
