extends Control
class_name InventoryCodexPreview

const PLAYER_TEXTURE := preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Idle/Idle-Sheet.png")
const PLAYER_ATTACK_TEXTURE := preload("res://assets/curated/game_own/world/legacy_fantasy/Character/Attack-01/Attack-01-Sheet.png")
const AUTO_ATTACK_SCENE := preload("res://scenes/combat/AutoAttackFeedback.tscn")
const FIRE_SCENE := preload("res://scenes/combat/vfx/FireUltimateVFX.tscn")
const ICE_SCENE := preload("res://scenes/combat/vfx/IceUltimateVFX.tscn")
const NAMED_SKILL_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const SWORD_WAVE_SPEED_MULTIPLIER := 1.10

var _entry: Dictionary = {}
var _effect: Node2D
var _phase := 0.0
var _replay_remaining := 0.0
var _action_elapsed := 1.0
var _effect_preview_size := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU)
	_action_elapsed += delta
	var kind := String(_entry.get("preview_kind", ""))
	if (
		is_instance_valid(_effect)
		and (
			kind in ["basic_attack", "attack_aura", "finisher", "passive_skill"]
			or not String(_entry.get("named_vfx_id", "")).is_empty()
		)
		and not _effect_preview_size.is_equal_approx(size)
	):
		_spawn_effect()
	if kind in [
		"basic_attack", "attack_aura", "technique", "passive_skill", "finisher",
		"fire_ultimate", "ice_ultimate",
	]:
		_replay_remaining -= delta
		if _replay_remaining <= 0.0:
			_spawn_effect()
	queue_redraw()


func show_entry(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	_replay_remaining = 0.0
	_clear_effect()
	if String(_entry.get("preview_kind", "")) in [
		"basic_attack", "attack_aura", "technique", "passive_skill", "finisher",
	]:
		_spawn_effect()
	queue_redraw()


func get_active_entry_id() -> String:
	return String(_entry.get("id", ""))


func get_preview_kind() -> String:
	return String(_entry.get("preview_kind", ""))


func get_effect_node_count() -> int:
	return 1 if is_instance_valid(_effect) else 0


func get_sword_wave_speed_multiplier() -> float:
	return SWORD_WAVE_SPEED_MULTIPLIER


func get_effect_origin_offset_from_preview_center() -> Vector2:
	if not is_instance_valid(_effect):
		return Vector2.ZERO
	return _effect.position - _preview_effect_center()


func get_active_named_vfx_id() -> String:
	if not is_instance_valid(_effect) or not _effect.has_method("get_profile_id"):
		return ""
	return String(_effect.call("get_profile_id"))


func get_active_effect_evolution_level() -> int:
	if not is_instance_valid(_effect) or not _effect.has_method("get_evolution_level"):
		return 0
	return int(_effect.call("get_evolution_level"))


func get_active_effect_buff_stacks() -> int:
	if not is_instance_valid(_effect) or not _effect.has_method("get_buff_stack_count"):
		return 0
	return int(_effect.call("get_buff_stack_count"))


func get_effect_travel_offset() -> Vector2:
	if not is_instance_valid(_effect) or not _effect.has_method("get_travel_offset"):
		return Vector2.ZERO
	return _effect.call("get_travel_offset") as Vector2


func is_effect_top_level() -> bool:
	return _effect.is_set_as_top_level() if is_instance_valid(_effect) else false


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
	if kind == "passive_skill" and String(_entry.get("named_vfx_id", "")).is_empty():
		var pulse := 38.0 + sin(_phase * 2.4) * 8.0
		draw_arc(center, pulse, 0, TAU, 40, Color(0.35, 0.85, 0.65, 0.62), 3.0)
		draw_arc(center, pulse + 13.0, 0, TAU, 40, Color(0.92, 0.78, 0.34, 0.26), 2.0)
	elif kind == "technique":
		_draw_technique_preview(center)
	_draw_character(center)


func _draw_character(center: Vector2) -> void:
	var kind := String(_entry.get("preview_kind", ""))
	var uses_attack_action := kind in [
		"basic_attack", "attack_aura", "technique", "finisher", "fire_ultimate", "ice_ultimate",
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
	if size.x < 64.0 or size.y < 64.0:
		_replay_remaining = 0.0
		return
	var kind := String(_entry.get("preview_kind", ""))
	var named_vfx_id := String(_entry.get("named_vfx_id", ""))
	if not named_vfx_id.is_empty():
		_spawn_named_skill(named_vfx_id)
		return
	if kind in ["basic_attack", "attack_aura", "finisher"]:
		_spawn_sword_wave(kind)
		return
	elif kind == "technique":
		_replay_remaining = 1.45
		return
	elif kind == "fire_ultimate":
		_effect = FIRE_SCENE.instantiate() as Node2D
	elif kind == "ice_ultimate":
		_effect = ICE_SCENE.instantiate() as Node2D
	else:
		return
	add_child(_effect)
	_effect.position = _preview_effect_center()
	_effect.set("radius", clampf(float(_entry.get("radius", 180.0)) * 0.42, 96.0, 190.0))
	_effect.set("intensity", 0.85)
	_effect.set("duration", 1.0)
	_effect.call_deferred("play")
	_effect_preview_size = size
	_replay_remaining = 2.25


func _spawn_sword_wave(kind: String) -> void:
	_effect = AUTO_ATTACK_SCENE.instantiate() as Node2D
	if _effect == null:
		return
	add_child(_effect)
	_effect.z_index = 6
	var local_origin := _preview_effect_center() + Vector2(34.0, 7.0)
	var local_target := local_origin + Vector2(minf(210.0, size.x * 0.32), 0.0)
	var elements: Array = _entry.get("elements", []) as Array
	var profile := {
		"elements": elements,
		"stack_count": int(_entry.get("stack_count", 3 if kind == "finisher" else 0)),
		"finisher": kind == "finisher",
		"finisher_name": String(_entry.get("name", "FINISHER")),
		"local_coordinates": true,
	}
	_effect.call(
		"play",
		local_origin,
		local_target,
		0,
		9 if kind == "finisher" else (3 if kind == "attack_aura" else 0),
		0,
		false,
		SWORD_WAVE_SPEED_MULTIPLIER,
		float(_entry.get("attack_size_multiplier", 1.0)),
		profile
	)
	_effect_preview_size = size
	_replay_remaining = 1.0 if kind != "finisher" else 1.3


func _spawn_named_skill(profile_id: String) -> void:
	_effect = NAMED_SKILL_SCENE.instantiate() as Node2D
	if _effect == null:
		return
	_effect.set("auto_free", false)
	add_child(_effect)
	_effect.z_index = 6
	_effect.position = _preview_effect_center()
	_effect.call(
		"play",
		profile_id,
		1,
		1.0,
		true,
		clampi(int(_entry.get("level", 1)), 1, 3),
		maxi(0, int(_entry.get("combo_stack", 0)))
	)
	_effect_preview_size = size
	_replay_remaining = 1.5


func _preview_effect_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.78 - 39.0)


func _draw_technique_preview(center: Vector2) -> void:
	var family := String(_entry.get("visual_family", "attack"))
	var cast_progress := clampf(_action_elapsed / 0.72, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_phase * 3.0)
	match family:
		"healing":
			_draw_healing_technique(center, cast_progress, pulse)
		"defense":
			_draw_defense_technique(center, cast_progress, pulse)
		"energy":
			_draw_energy_technique(center, cast_progress, pulse)
		"mobility":
			_draw_mobility_technique(center, cast_progress)
		"control":
			_draw_control_technique(center, cast_progress, pulse)
		"power":
			_draw_power_technique(center, cast_progress, pulse)
		_:
			_draw_power_technique(center, cast_progress, pulse)


func _draw_healing_technique(center: Vector2, progress: float, pulse: float) -> void:
	var radius := lerpf(18.0, 64.0, ease(progress, 0.55))
	draw_arc(center, radius, 0.0, TAU, 36, Color(0.38, 1.0, 0.58, 0.72), 4.0)
	draw_arc(center, radius * 0.72, 0.0, TAU, 32, Color(0.90, 1.0, 0.72, 0.54), 2.0)
	for mote_index in 8:
		var angle := TAU * float(mote_index) / 8.0 + _phase * 0.7
		var mote := center + Vector2.from_angle(angle) * radius * (0.55 + pulse * 0.18)
		draw_circle(mote, 2.0 + float(mote_index % 3), Color(0.72, 1.0, 0.62, 0.72))
	draw_line(center + Vector2(-11.0, -44.0), center + Vector2(-11.0, -14.0), Color.WHITE, 6.0)
	draw_line(center + Vector2(-26.0, -29.0), center + Vector2(4.0, -29.0), Color.WHITE, 6.0)


func _draw_defense_technique(center: Vector2, progress: float, pulse: float) -> void:
	var shield_center := center + Vector2(0.0, -24.0)
	var scale := lerpf(0.72, 1.0, ease(progress, 0.65))
	var shield := PackedVector2Array([
		shield_center + Vector2(-38.0, -34.0) * scale,
		shield_center + Vector2(38.0, -34.0) * scale,
		shield_center + Vector2(31.0, 20.0) * scale,
		shield_center + Vector2(0.0, 48.0) * scale,
		shield_center + Vector2(-31.0, 20.0) * scale,
	])
	draw_colored_polygon(shield, Color(0.24, 0.42, 0.52, 0.26 + pulse * 0.10))
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color(0.78, 0.94, 1.0, 0.82), 4.0)
	draw_arc(shield_center, 55.0 + pulse * 6.0, PI, TAU, 24, Color(0.94, 0.76, 0.32, 0.42), 2.0)


func _draw_energy_technique(center: Vector2, progress: float, pulse: float) -> void:
	var orbit_radius := lerpf(16.0, 58.0, ease(progress, 0.55))
	for orb_index in 6:
		var angle := TAU * float(orb_index) / 6.0 + _phase * 1.4
		var orb := center + Vector2.from_angle(angle) * orbit_radius
		draw_circle(orb, 5.0 + pulse * 2.0, Color(0.28, 0.84, 1.0, 0.82))
		draw_circle(orb, 2.0, Color.WHITE)
	draw_arc(center, orbit_radius, 0.0, TAU, 36, Color(1.0, 0.82, 0.30, 0.40), 2.0)


func _draw_mobility_technique(center: Vector2, progress: float) -> void:
	var reach := lerpf(24.0, 112.0, ease(progress, 0.42))
	for streak_index in 6:
		var y_offset := (float(streak_index) - 2.5) * 9.0
		var start := center + Vector2(-reach, y_offset - 22.0)
		var finish := center + Vector2(42.0 + float(streak_index % 3) * 10.0, y_offset - 14.0)
		draw_line(start, finish, Color(0.58, 0.94, 1.0, 0.30 + float(streak_index) * 0.07), 2.0 + float(streak_index % 2))
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(54.0, -16.0),
			center + Vector2(28.0, -32.0),
			center + Vector2(34.0, -16.0),
			center + Vector2(28.0, 0.0),
		]),
		Color(0.92, 1.0, 1.0, 0.88)
	)


func _draw_control_technique(center: Vector2, progress: float, pulse: float) -> void:
	var radius := lerpf(20.0, 78.0, ease(progress, 0.62))
	for ring_index in 3:
		draw_arc(
			center,
			radius + float(ring_index) * 12.0,
			0.0,
			TAU,
			40,
			Color(0.38 + float(ring_index) * 0.12, 0.72, 1.0, 0.58 - float(ring_index) * 0.12),
			3.0 - float(ring_index) * 0.45
		)
	for rune_index in 8:
		var angle := TAU * float(rune_index) / 8.0 - _phase * 0.55
		var rune := center + Vector2.from_angle(angle) * radius * (0.74 + pulse * 0.08)
		var tangent := Vector2.from_angle(angle).orthogonal()
		draw_line(rune - tangent * 5.0, rune + tangent * 5.0, Color(0.84, 0.96, 1.0, 0.76), 2.0)


func _draw_power_technique(center: Vector2, progress: float, pulse: float) -> void:
	var radius := lerpf(16.0, 68.0, ease(progress, 0.52))
	for ray_index in 10:
		var angle := TAU * float(ray_index) / 10.0 + _phase * 0.18
		var ray := Vector2.from_angle(angle)
		draw_line(
			center + ray * radius * 0.34,
			center + ray * radius * (0.76 + pulse * 0.24),
			Color(1.0, 0.54 + float(ray_index % 2) * 0.26, 0.18, 0.72),
			2.0 + float(ray_index % 3)
		)
	draw_arc(center, radius * 0.58, 0.0, TAU, 32, Color(1.0, 0.92, 0.56, 0.72), 4.0)


func _clear_effect() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
