extends Control
class_name InventoryCodexPreview

const PLAYER_TEXTURE := preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png")
const PLAYER_ATTACK_TEXTURE := preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Attack-01/Attack-01-Sheet.png")
const AUTO_ATTACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const FIRE_SCENE := preload("res://scenes/combat/vfx/FireUltimateVFX.tscn")
const ICE_SCENE := preload("res://scenes/combat/vfx/IceUltimateVFX.tscn")

var _entry: Dictionary = {}
var _effect: Node2D
var _phase := 0.0
var _replay_remaining := 0.0
var _action_elapsed := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU)
	_action_elapsed += delta
	if String(_entry.get("preview_kind", "")) in [
		"basic_attack", "attack_aura", "finisher", "fire_ultimate", "ice_ultimate",
	]:
		_replay_remaining -= delta
		if _replay_remaining <= 0.0:
			_spawn_effect()
	queue_redraw()


func show_entry(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_replay_remaining = 0.0
	_clear_effect()
	if String(_entry.get("preview_kind", "")) in ["basic_attack", "attack_aura", "finisher"]:
		_spawn_effect()
	queue_redraw()


func get_active_entry_id() -> String:
	return String(_entry.get("id", ""))


func get_preview_kind() -> String:
	return String(_entry.get("preview_kind", ""))


func get_effect_node_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("#10171a"))
	for index in 7:
		var y := size.y * (0.22 + float(index) * 0.1)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.28, 0.27, 0.2), 1.0)
	var floor_y := size.y * 0.78
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color("#24231e"))
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color("#96743d"), 2.0)
	var center := Vector2(size.x * 0.5, floor_y - 39.0)
	var kind := String(_entry.get("preview_kind", ""))
	if kind == "passive_skill":
		var pulse := 38.0 + sin(_phase * 2.4) * 8.0
		draw_arc(center, pulse, 0, TAU, 40, Color(0.35, 0.85, 0.65, 0.62), 3.0)
		draw_arc(center, pulse + 13.0, 0, TAU, 40, Color(0.92, 0.78, 0.34, 0.26), 2.0)
	_draw_character(center)


func _draw_character(center: Vector2) -> void:
	var kind := String(_entry.get("preview_kind", ""))
	var uses_attack_action := kind in [
		"basic_attack", "attack_aura", "finisher", "fire_ultimate", "ice_ultimate",
	]
	var action_active := uses_attack_action and _action_elapsed < 0.5
	var texture := PLAYER_ATTACK_TEXTURE if action_active else PLAYER_TEXTURE
	if texture == null:
		return
	var frame_count := 8 if action_active else 4
	var frame_size := Vector2(texture.get_width() / float(frame_count), texture.get_height())
	var frame := (
		mini(frame_count - 1, int(_action_elapsed * 16.0))
		if action_active
		else int(fmod(_phase * 5.0, float(frame_count)))
	)
	var source := Rect2(Vector2(frame_size.x * frame, 0.0), frame_size)
	var scale := 2.5
	var destination := Rect2(center - Vector2(frame_size.x * scale * 0.5, frame_size.y * scale * 0.5), frame_size * scale)
	draw_texture_rect_region(texture, destination, source)


func _spawn_effect() -> void:
	_clear_effect()
	_action_elapsed = 0.0
	var kind := String(_entry.get("preview_kind", ""))
	if kind in ["basic_attack", "attack_aura", "finisher"]:
		_spawn_sword_wave(kind)
		return
	elif kind == "fire_ultimate":
		_effect = FIRE_SCENE.instantiate() as Node2D
	elif kind == "ice_ultimate":
		_effect = ICE_SCENE.instantiate() as Node2D
	else:
		return
	add_child(_effect)
	_effect.set_as_top_level(true)
	_effect.global_position = global_position + Vector2(size.x * 0.5, size.y * 0.78 - 39.0)
	_effect.set("radius", clampf(float(_entry.get("radius", 180.0)) * 0.42, 96.0, 190.0))
	_effect.set("intensity", 0.85)
	_effect.set("duration", 1.0)
	_effect.call_deferred("play")
	_replay_remaining = 2.25


func _spawn_sword_wave(kind: String) -> void:
	_effect = AUTO_ATTACK_SCENE.instantiate() as Node2D
	if _effect == null:
		return
	add_child(_effect)
	_effect.set_as_top_level(true)
	_effect.z_index = 6
	var origin := global_position + Vector2(size.x * 0.5 + 34.0, size.y * 0.78 - 32.0)
	var target := origin + Vector2(minf(210.0, size.x * 0.32), -14.0)
	var elements: Array = _entry.get("elements", []) as Array
	var profile := {
		"elements": elements,
		"stack_count": int(_entry.get("stack_count", 3 if kind == "finisher" else 0)),
		"finisher": kind == "finisher",
		"finisher_name": String(_entry.get("name", "FINISHER")),
	}
	_effect.call(
		"play",
		origin,
		target,
		0,
		9 if kind == "finisher" else (3 if kind == "attack_aura" else 0),
		0,
		false,
		0.45,
		float(_entry.get("attack_size_multiplier", 1.0)),
		profile
	)
	_replay_remaining = 1.0 if kind != "finisher" else 1.3


func _clear_effect() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
