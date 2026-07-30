class_name EnemyBase
extends CharacterBody2D

signal defeated(enemy: Node, experience: int, gold: int)
signal health_changed(current: int, maximum: int)
signal hit_confirmed(damage: int, lethal: bool)
signal attack_telegraphed(pattern: StringName, duration: float)
signal attack_performed(pattern: StringName)

const ARCHETYPE_DATA := preload("res://scripts/monsters/enemy_archetype.gd")
const ULTIMATE_DEATH_HIT_HOLD := 0.065
const DEFAULT_ULTIMATE_IMPACT_DELAY := 0.44
const ULTIMATE_DEATH_DISSOLVE := 0.26
const ULTIMATE_DEATH_BURST_TAIL := 0.54
const STANDARD_DEATH_CLEANUP := 0.25

@export var archetype_id: StringName = &"sprout"
@export var gravity: float = 980.0
@export var navigation_jump_velocity := 620.0
@export var navigation_jump_cooldown := 0.55
@export var navigation_landing_grace := 0.45
@export var navigation_stuck_seconds := 0.28
@export var platform_target_height := 42.0
@export var platform_target_horizontal_range := 280.0
@export var horde_separation_radius := 64.0
@export var horde_separation_weight := 1.25
@export var horde_separation_refresh := 0.12

@onready var visual: CanvasItem = get_node_or_null("Visual") as CanvasItem
@onready var health_fill: ColorRect = get_node_or_null("HealthBar/Fill") as ColorRect
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox") as Area2D
@onready var attack_feedback: EnemyAttackFeedback = get_node_or_null("AttackFeedback") as EnemyAttackFeedback
@onready var damage_number: Label = get_node_or_null("DamageNumber") as Label
@onready var death_burst: CPUParticles2D = get_node_or_null("DeathBurst") as CPUParticles2D

var archetype: Resource
var health: int = 1
var target: Node2D
var phase: int = 1
var _cooldown := 0.0
var _pattern_index := 0
var _dying := false
var _attacking := false
var _slow_ratio := 0.0
var _slow_remaining := 0.0
var _stun_remaining := 0.0
var _burn_remaining := 0.0
var _burn_damage := 0
var _burn_tick_remaining := 1.0
var _poison_remaining := 0.0
var _poison_damage := 0
var _poison_tick_remaining := 0.75
var _attack_generation := 0
var _telegraphed_target_position := Vector2.ZERO
var _navigation_jump_remaining := 0.0
var _navigation_stalled_seconds := 0.0
var _separation_refresh_remaining := 0.0
var _cached_separation_bias := 0.0
var _hit_tween: Tween
var _damage_number_tween: Tween
var _pending_hit_presentation: Dictionary = {}
var _death_presentation_profile: Dictionary = {}
var _death_presentation_root: Node2D
var _death_presentation_phase := &""
var _death_presentation_active := false
var _defeat_gameplay_settled := false


func _ready() -> void:
	if archetype == null:
		configure_archetype(archetype_id)
	target = get_tree().get_first_node_in_group("Player") as Node2D
	_separation_refresh_remaining = (
		float(get_instance_id() % 12) / 12.0 * horde_separation_refresh
	)


func configure_archetype(id: StringName) -> bool:
	var catalog: Dictionary = ARCHETYPE_DATA.autumn_catalog()
	if not catalog.has(id):
		return false
	apply_archetype(catalog[id])
	return true


func apply_archetype(data: Resource) -> void:
	archetype = data
	archetype_id = data.get("archetype_id") as StringName
	health = int(data.get("max_health"))
	_pattern_index = 0
	_dying = false
	_pending_hit_presentation.clear()
	_death_presentation_profile.clear()
	_death_presentation_phase = &""
	_death_presentation_active = false
	_defeat_gameplay_settled = false
	_apply_visual()
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if _dying:
		return
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	_stun_remaining = maxf(0.0, _stun_remaining - delta)
	_update_burn(delta)
	_update_poison(delta)
	_navigation_jump_remaining = maxf(0.0, _navigation_jump_remaining - delta)
	_separation_refresh_remaining = maxf(0.0, _separation_refresh_remaining - delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	_cooldown = maxf(0.0, _cooldown - delta)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("Player") as Node2D
		velocity.x = 0.0
	elif _stun_remaining > 0.0:
		velocity.x = 0.0
	else:
		_update_behavior()
	var was_on_floor := is_on_floor()
	var previous_x := global_position.x
	var wanted_horizontal_motion := absf(velocity.x) > 1.0
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_navigation_jump_remaining = maxf(
			_navigation_jump_remaining,
			navigation_landing_grace
		)
	_update_navigation_recovery(delta, previous_x, wanted_horizontal_motion)


func _update_behavior() -> void:
	if archetype == null or _attacking:
		return
	var distance := global_position.distance_to(target.global_position)
	var attack_range := float(archetype.get("attack_range"))
	var detection_range := float(archetype.get("detection_range"))
	var target_offset := target.global_position - global_position
	if (
		distance <= attack_range
		and absf(target_offset.y) <= 54.0
		and _cooldown <= 0.0
	):
		_begin_attack()
		return
	if distance > detection_range and not bool(get_meta("persistent_pursuit", false)):
		velocity.x = 0.0
		return

	var direction := signf(target_offset.x)
	if is_zero_approx(direction):
		direction = 1.0
	var separation_bias := _get_cached_horde_separation_bias()
	var steering := clampf(
		direction + separation_bias * horde_separation_weight,
		-1.0,
		1.0
	)
	var behavior := archetype.get("behavior") as StringName
	var pursuit_jump_reason := get_pursuit_jump_reason(
		behavior,
		target_offset,
		attack_range
	)
	if (
		behavior == &"ranged"
		and absf(target_offset.y) <= platform_target_height
		and distance < attack_range * 0.72
	):
		velocity.x = clampf(
			-direction * 0.65 + separation_bias * horde_separation_weight,
			-1.0,
			1.0
		) * float(archetype.get("speed")) * _movement_multiplier()
	elif (
		is_on_floor()
		and _navigation_jump_remaining <= 0.0
		and pursuit_jump_reason != &""
	):
		velocity.x = steering * float(archetype.get("speed")) * _movement_multiplier()
		velocity.y = -navigation_jump_velocity * 0.72
		_navigation_jump_remaining = (
			maxf(navigation_jump_cooldown, 1.1)
			if pursuit_jump_reason == &"pounce"
			else navigation_jump_cooldown
		)
	else:
		velocity.x = steering * float(archetype.get("speed")) * _movement_multiplier()
	if visual != null:
		visual.scale.x = absf(visual.scale.x) * direction


func get_horde_separation_bias(neighbors: Array) -> float:
	var bias := 0.0
	for neighbor_variant in neighbors:
		if not neighbor_variant is Node2D:
			continue
		var neighbor := neighbor_variant as Node2D
		if neighbor == self or not is_instance_valid(neighbor):
			continue
		var offset := global_position - neighbor.global_position
		if absf(offset.y) > 80.0 or absf(offset.x) >= horde_separation_radius:
			continue
		var away := signf(offset.x)
		if is_zero_approx(away):
			away = -1.0 if get_instance_id() < neighbor.get_instance_id() else 1.0
		bias += away * (1.0 - absf(offset.x) / horde_separation_radius)
	return clampf(bias, -1.0, 1.0)


func _get_cached_horde_separation_bias() -> float:
	if _separation_refresh_remaining > 0.0 or not is_inside_tree():
		return _cached_separation_bias
	_cached_separation_bias = get_horde_separation_bias(
		get_tree().get_nodes_in_group("Enemies")
	)
	_separation_refresh_remaining = horde_separation_refresh
	return _cached_separation_bias


func get_navigation_jump_reason(
	target_offset: Vector2,
	stalled_seconds: float,
	touching_wall: bool
) -> StringName:
	if touching_wall:
		return &"obstacle"
	if stalled_seconds >= navigation_stuck_seconds:
		return &"stuck"
	if (
		target_offset.y <= -platform_target_height
		and absf(target_offset.x) <= platform_target_horizontal_range
	):
		return &"platform"
	return &""


func get_pursuit_jump_reason(
	behavior: StringName,
	target_offset: Vector2,
	attack_range: float
) -> StringName:
	if behavior != &"leap":
		return &""
	if (
		target_offset.y <= -platform_target_height
		and absf(target_offset.x) <= platform_target_horizontal_range
	):
		return &"platform"
	if (
		absf(target_offset.y) <= platform_target_height
		and absf(target_offset.x) >= attack_range * 1.6
	):
		return &"pounce"
	return &""


func _update_navigation_recovery(
	delta: float,
	previous_x: float,
	wanted_horizontal_motion: bool
) -> void:
	if (
		target == null
		or not is_instance_valid(target)
		or _attacking
		or _stun_remaining > 0.0
	):
		_navigation_stalled_seconds = 0.0
		return
	if is_on_floor() and wanted_horizontal_motion:
		var horizontal_progress := absf(global_position.x - previous_x)
		if horizontal_progress < 0.5:
			_navigation_stalled_seconds += delta
		else:
			_navigation_stalled_seconds = 0.0
	elif not is_on_floor():
		_navigation_stalled_seconds = 0.0
	if not is_on_floor() or _navigation_jump_remaining > 0.0:
		return
	var reason := get_navigation_jump_reason(
		target.global_position - global_position,
		_navigation_stalled_seconds,
		is_on_wall()
	)
	if reason == &"":
		return
	velocity.y = -navigation_jump_velocity
	_navigation_jump_remaining = navigation_jump_cooldown
	_navigation_stalled_seconds = 0.0


func perform_next_attack() -> StringName:
	if archetype == null:
		return &""
	var patterns := archetype.get("attack_patterns") as Array
	if patterns.is_empty():
		return &""
	var pattern := patterns[_pattern_index % patterns.size()] as StringName
	_pattern_index += 1
	attack_telegraphed.emit(pattern, float(archetype.get("telegraph_time")))
	return pattern


func _begin_attack() -> void:
	_attacking = true
	_attack_generation += 1
	var generation := _attack_generation
	velocity.x = 0.0
	_cooldown = float(archetype.get("attack_cooldown"))
	var pattern := perform_next_attack()
	var direction := signf(target.global_position.x - global_position.x) if target != null else 1.0
	if is_zero_approx(direction):
		direction = 1.0
	_telegraphed_target_position = target.global_position if target != null else global_position
	if attack_feedback != null:
		attack_feedback.show_telegraph(
			pattern,
			_get_attack_telegraph_time(),
			_attack_reach(pattern),
			direction,
			_telegraphed_target_position - global_position
		)
	await get_tree().create_timer(_get_attack_telegraph_time()).timeout
	if _dying or generation != _attack_generation:
		return
	if attack_feedback != null:
		attack_feedback.show_impact(pattern, _attack_reach(pattern), direction)
	_apply_attack_pattern(pattern, direction)
	attack_performed.emit(pattern)
	_attacking = false


func _apply_attack_pattern(pattern: StringName, telegraphed_direction: float = 0.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var reach := _attack_reach(pattern)
	var damage := int(archetype.get("attack_damage"))
	match pattern:
		&"rush":
			velocity.x = telegraphed_direction * float(archetype.get("speed")) * 2.4
		&"shockwave":
			damage = int(round(damage * 0.8))
		&"cleave":
			damage = int(round(damage * 1.2))
	var target_offset := target.global_position - global_position
	var inside_telegraphed_side := (
		is_zero_approx(telegraphed_direction)
		or target_offset.x * telegraphed_direction >= -8.0
	)
	if (
		inside_telegraphed_side
		and target_offset.length() <= reach
		and absf(target_offset.y) <= _attack_half_height(pattern) + 12.0
		and target.has_method("take_hit")
	):
		target.call("take_hit", damage, global_position, 220.0)


func _attack_reach(pattern: StringName) -> float:
	var reach := float(archetype.get("attack_range")) if archetype != null else 60.0
	match pattern:
		&"thorn_volley":
			reach *= 1.25
		&"shockwave":
			reach *= 1.65
	return reach


func _attack_half_height(pattern: StringName) -> float:
	match pattern:
		&"thorn_volley":
			return 13.0
		&"shockwave":
			return 34.0
		&"cleave":
			return 42.0
		_:
			return 24.0


func take_hit(raw_damage: int, source_position: Vector2, knockback: float = 180.0) -> int:
	if _dying or archetype == null:
		return 0
	var applied := maxi(1, raw_damage - int(archetype.get("defense")))
	health = maxi(0, health - applied)
	velocity.x = signf(global_position.x - source_position.x) * knockback
	health_changed.emit(health, int(archetype.get("max_health")))
	_update_health_bar()
	var hit_presentation := _pending_hit_presentation.duplicate(true)
	_pending_hit_presentation.clear()
	if health <= 0 and String(hit_presentation.get("kind", "")) == "ultimate":
		_death_presentation_profile = hit_presentation
	_play_hit_feedback(applied, health <= 0)
	_after_damage()
	if health <= 0:
		_die()
	return applied


func prepare_hit_presentation(profile: Dictionary) -> void:
	if _dying:
		return
	_pending_hit_presentation = profile.duplicate(true)


func get_defeat_presentation_state() -> Dictionary:
	var impact_delay := _ultimate_death_impact_delay()
	return {
		"active": _death_presentation_active,
		"phase": String(_death_presentation_phase),
		"timeline": String(_death_presentation_profile.get("timeline", "")),
		"element": String(_death_presentation_profile.get("element", "normal")),
		"ignores_time_scale": _death_presentation_active,
		"impact_delay_seconds": (
			impact_delay
			if _death_presentation_active
			else 0.0
		),
		"cleanup_seconds": (
			_ultimate_death_cleanup_seconds()
			if _death_presentation_active
			else STANDARD_DEATH_CLEANUP
		),
		"gameplay_settled": _defeat_gameplay_settled,
		"presentation_node_count": (
			_death_presentation_root.get_child_count()
			if is_instance_valid(_death_presentation_root)
			else 0
		),
	}


func _after_damage() -> void:
	pass


func _play_hit_feedback(damage: int, lethal: bool) -> void:
	hit_confirmed.emit(damage, lethal)
	if damage_number != null:
		if _damage_number_tween != null and _damage_number_tween.is_valid():
			_damage_number_tween.kill()
		damage_number.text = "-%d" % damage
		damage_number.position = Vector2(-46.0, -112.0)
		damage_number.modulate = Color.WHITE
		damage_number.visible = true
		damage_number.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.2) if lethal else Color(1.0, 0.97, 0.88)
		)
		_damage_number_tween = create_tween()
		_damage_number_tween.set_ignore_time_scale(
			lethal and not _death_presentation_profile.is_empty()
		)
		_damage_number_tween.set_parallel(true)
		_damage_number_tween.tween_property(
			damage_number,
			"position:y",
			-148.0 if lethal else -136.0,
			0.28
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_damage_number_tween.tween_property(
			damage_number,
			"modulate:a",
			0.0,
			0.22
		).set_delay(0.12)
	if visual == null or archetype == null:
		return
	if _hit_tween != null and _hit_tween.is_valid():
		_hit_tween.kill()
	var base_color := archetype.get("visual_color") as Color
	var base_scale := archetype.get("visual_scale") as Vector2
	visual.modulate = Color(2.4, 2.4, 2.4, 1.0)
	visual.scale = base_scale * (Vector2(1.28, 0.78) if lethal else Vector2(1.18, 0.86))
	if lethal and not _death_presentation_profile.is_empty():
		_play_ultimate_death_presentation(base_color, base_scale)
		return
	_hit_tween = create_tween()
	_hit_tween.set_parallel(true)
	if lethal:
		if death_burst != null:
			death_burst.restart()
			death_burst.emitting = true
		_hit_tween.tween_property(visual, "scale", base_scale * 1.55, 0.22)
		_hit_tween.tween_property(visual, "rotation", 0.16 * signf(velocity.x), 0.22)
		_hit_tween.tween_property(
			visual,
			"modulate",
			Color(base_color.r, base_color.g, base_color.b, 0.0),
			0.22
		)
	else:
		_hit_tween.tween_property(
			visual,
			"modulate",
			base_color,
			0.14
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hit_tween.tween_property(
			visual,
			"scale",
			base_scale,
			0.14
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_ultimate_death_presentation(
	base_color: Color,
	base_scale: Vector2
) -> void:
	_death_presentation_active = true
	_death_presentation_phase = &"hit"
	var palette := _ultimate_death_palette(
		String(_death_presentation_profile.get("element", "normal"))
	)
	var impact_delay := _ultimate_death_impact_delay()
	var cleanup_seconds := _ultimate_death_cleanup_seconds()
	if death_burst != null:
		death_burst.color = palette[1]
		death_burst.speed_scale = clampf(
			1.0 / maxf(Engine.time_scale, 0.12),
			1.0,
			8.5
		)
		death_burst.emitting = false
	_build_ultimate_death_parts(palette, impact_delay, cleanup_seconds)

	_hit_tween = create_tween()
	_hit_tween.set_ignore_time_scale(true)
	_hit_tween.set_parallel(true)
	_hit_tween.tween_property(
		visual,
		"scale",
		base_scale * Vector2(1.06, 0.98),
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(
		visual,
		"modulate",
		base_color,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(
		visual,
		"scale",
		base_scale * Vector2(2.10, 1.58),
		ULTIMATE_DEATH_DISSOLVE
	).set_delay(impact_delay).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_hit_tween.tween_property(
		visual,
		"rotation",
		0.22 * (-1.0 if velocity.x < 0.0 else 1.0),
		ULTIMATE_DEATH_DISSOLVE
	).set_delay(impact_delay)
	_hit_tween.tween_property(
		visual,
		"modulate",
		palette[2],
		0.04
	).set_delay(impact_delay)
	_hit_tween.tween_property(
		visual,
		"modulate",
		Color(base_color.r, base_color.g, base_color.b, 0.0),
		maxf(0.05, cleanup_seconds - impact_delay - 0.04)
	).set_delay(impact_delay + 0.04)

	var phase_tween := create_tween()
	phase_tween.set_ignore_time_scale(true)
	phase_tween.tween_interval(ULTIMATE_DEATH_HIT_HOLD)
	phase_tween.tween_callback(
		_set_death_presentation_phase.bind(&"impact_hold")
	)
	phase_tween.tween_interval(
		maxf(0.0, impact_delay - ULTIMATE_DEATH_HIT_HOLD)
	)
	phase_tween.tween_callback(_begin_ultimate_death_impact)
	phase_tween.tween_interval(ULTIMATE_DEATH_DISSOLVE)
	phase_tween.tween_callback(_set_death_presentation_phase.bind(&"burst"))


func _build_ultimate_death_parts(
	palette: Array[Color],
	impact_delay: float,
	cleanup_seconds: float
) -> void:
	if is_instance_valid(_death_presentation_root):
		_death_presentation_root.queue_free()
	_death_presentation_root = Node2D.new()
	_death_presentation_root.name = "UltimateDeathPresentation"
	_death_presentation_root.position = Vector2(0.0, -38.0)
	_death_presentation_root.z_index = 15
	add_child(_death_presentation_root)

	var core := Polygon2D.new()
	core.name = "ImpactCore"
	core.polygon = PackedVector2Array([
		Vector2(0.0, -26.0),
		Vector2(22.0, 0.0),
		Vector2(0.0, 26.0),
		Vector2(-22.0, 0.0),
	])
	core.color = palette[2]
	core.modulate.a = 0.0
	_death_presentation_root.add_child(core)

	for ring_index in 2:
		var ring := Line2D.new()
		ring.name = "DissolveRing%d" % (ring_index + 1)
		ring.closed = true
		ring.width = 6.0 - float(ring_index) * 1.5
		ring.default_color = palette[ring_index]
		ring.points = _death_ring_points(32.0 + float(ring_index) * 16.0)
		ring.scale = Vector2.ONE * (0.48 + float(ring_index) * 0.10)
		ring.modulate.a = 0.0
		_death_presentation_root.add_child(ring)

	for shard_index in 8:
		var shard := Polygon2D.new()
		shard.name = "BurstShard%d" % (shard_index + 1)
		shard.polygon = PackedVector2Array([
			Vector2(-5.0, -4.0),
			Vector2(19.0 + float(shard_index % 3) * 4.0, 0.0),
			Vector2(-5.0, 4.0),
		])
		shard.color = palette[1 if shard_index % 2 == 0 else 2]
		shard.rotation = TAU * float(shard_index) / 8.0
		shard.scale = Vector2(0.9, 0.9)
		shard.modulate.a = 0.0
		_death_presentation_root.add_child(shard)

	var parts_tween := _death_presentation_root.create_tween()
	parts_tween.set_ignore_time_scale(true)
	parts_tween.set_parallel(true)
	for child_index in _death_presentation_root.get_child_count():
		var part := _death_presentation_root.get_child(child_index) as CanvasItem
		if part == null:
			continue
		if part is Line2D:
			parts_tween.tween_property(
				part,
				"modulate:a",
				0.9,
				0.04
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"scale",
				Vector2.ONE * (1.94 + float(child_index) * 0.16),
				cleanup_seconds - impact_delay
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"modulate:a",
				0.0,
				0.28
			).set_delay(impact_delay + 0.16)
		elif part is Polygon2D and child_index > 2:
			var angle := (part as Polygon2D).rotation
			parts_tween.tween_property(
				part,
				"modulate:a",
				1.0,
				0.04
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"position",
				Vector2.from_angle(angle) * (112.0 + float(child_index) * 7.0),
				cleanup_seconds - impact_delay
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"rotation",
				angle + (-0.9 if child_index % 2 == 0 else 0.9),
				cleanup_seconds - impact_delay
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"modulate:a",
				0.0,
				0.20
			).set_delay(impact_delay + 0.28)
		else:
			parts_tween.tween_property(
				part,
				"modulate:a",
				0.22,
				0.04
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"scale",
				Vector2.ONE * 1.65,
				ULTIMATE_DEATH_DISSOLVE
			).set_delay(impact_delay)
			parts_tween.tween_property(
				part,
				"modulate:a",
				0.0,
				0.25
			).set_delay(impact_delay + 0.10)


func _death_ring_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for point_index in 24:
		var angle := TAU * float(point_index) / 24.0
		var irregularity := 1.0 + sin(angle * 5.0) * 0.08
		points.append(Vector2.from_angle(angle) * radius * irregularity)
	return points


func _ultimate_death_palette(element: String) -> Array[Color]:
	match element:
		"fire":
			return [
				Color(1.0, 0.26, 0.04, 0.92),
				Color(1.0, 0.58, 0.08, 0.94),
				Color(1.0, 0.94, 0.58, 1.0),
			]
		"ice", "water":
			return [
				Color(0.14, 0.62, 1.0, 0.88),
				Color(0.38, 0.90, 1.0, 0.96),
				Color(0.92, 1.0, 1.0, 1.0),
			]
		"lightning", "light":
			return [
				Color(0.48, 0.28, 1.0, 0.90),
				Color(0.82, 0.66, 1.0, 0.96),
				Color(1.0, 0.98, 0.72, 1.0),
			]
		"poison":
			return [
				Color(0.24, 0.68, 0.08, 0.90),
				Color(0.54, 1.0, 0.20, 0.94),
				Color(0.92, 1.0, 0.62, 1.0),
			]
		_:
			return [
				Color(0.46, 0.82, 1.0, 0.88),
				Color(1.0, 0.72, 0.18, 0.94),
				Color(1.0, 1.0, 1.0, 1.0),
			]


func _set_death_presentation_phase(value: StringName) -> void:
	if _death_presentation_active:
		_death_presentation_phase = value


func _begin_ultimate_death_impact() -> void:
	if not _death_presentation_active:
		return
	_death_presentation_phase = &"dissolve"
	if death_burst == null:
		return
	death_burst.restart()
	death_burst.emitting = true


func _ultimate_death_impact_delay() -> float:
	return clampf(
		float(_death_presentation_profile.get(
			"impact_delay_seconds",
			DEFAULT_ULTIMATE_IMPACT_DELAY
		)),
		ULTIMATE_DEATH_HIT_HOLD,
		1.25
	)


func _ultimate_death_cleanup_seconds() -> float:
	return _ultimate_death_impact_delay() + ULTIMATE_DEATH_BURST_TAIL


func apply_status(status_id: String, effect: Dictionary) -> void:
	var duration := maxf(0.0, float(effect.get("duration", 0.0)))
	match status_id:
		"stun":
			_stun_remaining = maxf(_stun_remaining, duration)
		"burn":
			_burn_remaining = maxf(_burn_remaining, duration)
			_burn_damage = maxi(_burn_damage, int(effect.get("damage", 1)))
			_burn_tick_remaining = minf(_burn_tick_remaining, 1.0)
		"poison":
			_poison_remaining = maxf(_poison_remaining, duration)
			_poison_damage = maxi(_poison_damage, int(effect.get("damage", 1)))
			_poison_tick_remaining = minf(_poison_tick_remaining, 0.75)
		_:
			_slow_ratio = clampf(float(effect.get("ratio", 0.0)), 0.0, 0.95)
			_slow_remaining = maxf(_slow_remaining, duration)


func get_status_snapshot() -> Dictionary:
	return {
		"slow_ratio": _slow_ratio,
		"slow_remaining": _slow_remaining,
		"stun_remaining": _stun_remaining,
		"burn_remaining": _burn_remaining,
		"poison_remaining": _poison_remaining,
	}


func reset_encounter(spawn_position: Vector2) -> void:
	if archetype == null or _dying:
		return
	_attack_generation += 1
	_attacking = false
	if attack_feedback != null:
		attack_feedback.cancel()
	_cooldown = 0.0
	_slow_ratio = 0.0
	_slow_remaining = 0.0
	_stun_remaining = 0.0
	_burn_remaining = 0.0
	_burn_damage = 0
	_burn_tick_remaining = 1.0
	_poison_remaining = 0.0
	_poison_damage = 0
	_poison_tick_remaining = 0.75
	_navigation_jump_remaining = 0.0
	_navigation_stalled_seconds = 0.0
	_separation_refresh_remaining = 0.0
	_cached_separation_bias = 0.0
	health = int(archetype.get("max_health"))
	position = spawn_position
	velocity = Vector2.ZERO
	health_changed.emit(health, int(archetype.get("max_health")))
	_update_health_bar()


func _movement_multiplier() -> float:
	return 1.0 - _slow_ratio if _slow_remaining > 0.0 else 1.0


func _update_burn(delta: float) -> void:
	if _burn_remaining <= 0.0 or _burn_damage <= 0:
		return
	_burn_remaining = maxf(0.0, _burn_remaining - delta)
	_burn_tick_remaining -= delta
	if _burn_tick_remaining > 0.0:
		return
	_burn_tick_remaining += 1.0
	take_hit(_burn_damage, global_position, 0.0)


func _update_poison(delta: float) -> void:
	if _poison_remaining <= 0.0 or _poison_damage <= 0:
		return
	_poison_remaining = maxf(0.0, _poison_remaining - delta)
	_poison_tick_remaining -= delta
	if _poison_tick_remaining > 0.0:
		return
	_poison_tick_remaining += 0.75
	take_hit(_poison_damage, global_position, 0.0)


func _get_attack_telegraph_time() -> float:
	return float(archetype.get("telegraph_time")) if archetype != null else 0.0


func _before_defeated() -> void:
	pass


func _die() -> void:
	if _dying:
		return
	_dying = true
	if attack_feedback != null:
		attack_feedback.cancel()
	collision_layer = 0
	collision_mask = 0
	if hurtbox != null:
		hurtbox.monitorable = false
	var health_bar := get_node_or_null("HealthBar") as CanvasItem
	if health_bar != null:
		health_bar.visible = false
	_before_defeated()
	_defeat_gameplay_settled = true
	defeated.emit(
		self,
		int(archetype.get("experience_reward")),
		int(archetype.get("gold_reward"))
	)
	var uses_ultimate_presentation := _death_presentation_active
	await get_tree().create_timer(
		_ultimate_death_cleanup_seconds()
			if uses_ultimate_presentation
			else STANDARD_DEATH_CLEANUP,
		true,
		false,
		uses_ultimate_presentation
	).timeout
	queue_free()


func _apply_visual() -> void:
	if visual == null or archetype == null:
		return
	visual.modulate = archetype.get("visual_color") as Color
	visual.scale = archetype.get("visual_scale") as Vector2


func _update_health_bar() -> void:
	if health_fill == null or archetype == null:
		return
	health_fill.size.x = 68.0 * float(health) / float(maxi(1, int(archetype.get("max_health"))))
