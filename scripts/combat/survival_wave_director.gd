class_name SurvivalWaveDirector
extends EncounterDirector

signal survival_time_changed(
	remaining: float,
	total: float,
	alive: int,
	cap: int,
	final_rush: bool
)
signal elite_spawned(elite: Node, remaining: float)
signal boss_spawned(boss: Node, completion_boss: bool, remaining: float)
signal boss_defeated(world_position: Vector2, completion_boss: bool)
signal boss_stage_completed
signal experience_gem_spawned(gem: Node, value: int)
signal survival_pickup_spawned(pickup: Node, item_id: StringName)
signal survival_pickup_collected(item_id: StringName)
signal reward_bag_spawned(pickup: Node, kind: StringName, reward: Dictionary)
signal reward_bag_collected(kind: StringName, reward: Dictionary)

const OPENING_SPAWN_COUNT := 30
const STRONG_ENEMY_VARIANTS: Array[StringName] = [
	&"thornling", &"charger", &"grove_shaman",
]
const STAGE_BOSS_VARIANTS: Array[StringName] = [
	&"heartwood_harbinger", &"thorn_colossus", &"ember_warden",
]
const MONSTER_MATERIALS := {
	"sprout": "autumn_wood",
	"hopper": "stone",
	"moth_swarm": "magic_shard",
	"thornling": "autumn_wood",
	"charger": "stone",
	"grove_shaman": "magic_shard",
	"elite": "autumn_core",
	"guardian": "autumn_core",
}

@export_range(30.0, 1800.0, 1.0) var survival_duration := 510.0
@export_range(10.0, 120.0, 1.0) var final_rush_duration := 30.0
@export var scheduled_elite_times: Array[float] = [
	60.0, 120.0, 180.0, 240.0, 300.0, 360.0, 420.0, 480.0,
]
@export var scheduled_boss_times: Array[float] = [
	90.0, 180.0, 300.0, 360.0, 420.0, 480.0,
]
@export_range(2.0, 60.0, 0.5) var final_rush_elite_interval := 7.5
@export_range(5.0, 60.0, 0.5) var final_rush_boss_interval := 15.0
@export_range(1, 120, 1) var base_density_cap := 48
@export_range(1, 240, 1) var maximum_density_cap := 170
@export_range(0, 100, 1) var final_rush_density_bonus := 50
@export_range(0.05, 5.0, 0.05) var base_spawn_interval := 0.35
@export_range(0.05, 5.0, 0.01) var minimum_spawn_interval := 0.08
@export_range(0.1, 1.0, 0.05) var final_rush_spawn_interval_multiplier := 0.40
@export_range(1, 24, 1) var base_spawn_batch := 10
@export_range(1, 28, 1) var maximum_spawn_batch := 20
@export_range(1.0, 600.0, 0.5) var scheduled_horde_time := 90.0
@export_range(2.0, 30.0, 0.5) var scheduled_horde_duration := 10.0
@export_range(0, 160, 1) var scheduled_horde_density_bonus := 70
@export_range(0, 64, 1) var scheduled_horde_batch_bonus := 28
@export_range(0.05, 1.0, 0.01) var scheduled_horde_interval_multiplier := 0.18
@export_range(1.0, 5.0, 0.25) var scheduled_horde_experience_multiplier := 2.0
@export_range(2.0, 30.0, 0.5) var post_boss_horde_duration := 12.0
@export_range(0, 160, 1) var post_boss_horde_density_bonus := 85
@export_range(0, 64, 1) var post_boss_horde_batch_bonus := 34
@export_range(0.05, 1.0, 0.01) var post_boss_horde_interval_multiplier := 0.15
@export_range(1.0, 8.0, 0.25) var post_boss_experience_multiplier := 3.0
@export_range(1.0, 30.0, 0.1) var base_normal_health_multiplier := 10.0
@export_range(1.0, 40.0, 0.1) var maximum_normal_health_multiplier := 26.0
@export_range(0.25, 2.0, 0.05) var normal_health_curve_exponent := 0.85
@export var normal_enemy_unlocks: Dictionary = {
	"sprout": 0.0,
	"hopper": 0.0,
	"moth_swarm": 0.0,
	"thornling": 90.0,
	"charger": 210.0,
	"grove_shaman": 330.0,
}
@export var experience_gem_scene: PackedScene = preload("res://scenes/combat/ExperienceGem.tscn")
@export var survival_pickup_scene: PackedScene = preload("res://scenes/combat/SurvivalPickup.tscn")
@export_range(0.0, 1.0, 0.005) var normal_pickup_drop_chance := 0.16
@export_range(0.0, 1.0, 0.005) var normal_money_bag_chance := 0.06
@export_range(0.0, 1.0, 0.005) var elite_money_bag_chance := 0.65
@export_range(0.0, 1.0, 0.005) var boss_money_bag_chance := 0.90
@export_range(0.0, 1.0, 0.005) var normal_material_bag_chance := 0.10
@export_range(0.0, 1.0, 0.005) var elite_material_bag_chance := 0.45
@export_range(0.0, 1.0, 0.005) var boss_material_bag_chance := 0.85
@export var spawn_around_player := false
@export var spawn_route_left := 0.0
@export var spawn_route_right := 0.0
@export var spawn_floor_y := 470.0
@export var spawn_perimeter_min := 680.0
@export var spawn_perimeter_max := 820.0
@export var recycle_distance := 1200.0
@export var recycle_interval := 0.35

var _time_remaining := 0.0
var _spawn_remaining := 0.0
var _recycle_remaining := 0.0
var _survival_elapsed := 0.0
var _spawned_elite_count := 0
var _spawned_boss_count := 0
var _completion_boss_spawn_count := 0
var _elite_defeat_count := 0
var _scheduled_elite_index := 0
var _scheduled_boss_index := 0
var _elite_schedule: Array[float] = []
var _boss_schedule: Array[float] = []
var _next_final_rush_elite_time := INF
var _next_final_rush_boss_time := INF
var _final_rush_started := false
var _exit_unlocked := false
var _survival_completed := false
var _rng := RandomNumberGenerator.new()
var _difficulty_tier := 1
var _post_boss_horde_remaining := 0.0


func configure_difficulty_tier(tier: int) -> void:
	_difficulty_tier = clampi(tier, 1, 4)


func _process(delta: float) -> void:
	super._process(delta)
	if _running and not get_tree().paused:
		advance_survival(delta)


func start_encounter() -> bool:
	if _running or survival_duration <= 0.0:
		return false
	_running = true
	_wave_index = 0
	_experience = 0
	_gold = 0
	_spawned_elite_count = 0
	_spawned_boss_count = 0
	_completion_boss_spawn_count = 0
	_elite_defeat_count = 0
	_scheduled_elite_index = 0
	_scheduled_boss_index = 0
	_elite_schedule = scheduled_elite_times.duplicate()
	_boss_schedule = scheduled_boss_times.duplicate()
	_elite_schedule.sort()
	_boss_schedule.sort()
	_next_final_rush_elite_time = INF
	_next_final_rush_boss_time = INF
	_final_rush_started = false
	_exit_unlocked = false
	_survival_completed = false
	_survival_elapsed = 0.0
	_post_boss_horde_remaining = 0.0
	_time_remaining = survival_duration
	_spawn_remaining = 0.0
	_recycle_remaining = 0.0
	_engaged = false
	_disengage_remaining = -1.0
	_spawn_positions.clear()
	_rng.seed = int(Time.get_ticks_usec() ^ get_instance_id())
	_spawn_until_cap(mini(OPENING_SPAWN_COUNT, get_current_density_cap()))
	encounter_started.emit(1)
	_emit_survival_time()
	return true


func advance_survival(delta: float) -> void:
	if not _running:
		return
	var safe_delta := maxf(0.0, delta)
	_post_boss_horde_remaining = maxf(0.0, _post_boss_horde_remaining - safe_delta)
	var previous_elapsed := _survival_elapsed
	_survival_elapsed = minf(survival_duration, _survival_elapsed + safe_delta)
	_time_remaining = maxf(0.0, survival_duration - _survival_elapsed)
	_recycle_remaining -= safe_delta
	if _recycle_remaining <= 0.0:
		_recycle_remaining = maxf(0.1, recycle_interval)
		_recycle_distant_enemies()
	_spawn_scheduled_events(previous_elapsed, _survival_elapsed)
	_spawn_final_rush_events(previous_elapsed, _survival_elapsed)
	if _time_remaining <= 0.0:
		_complete_survival()
	else:
		_spawn_remaining -= safe_delta
		var spawn_passes := 0
		while _spawn_remaining <= 0.0 and spawn_passes < 8:
			_spawn_remaining += _current_spawn_interval()
			_spawn_until_cap(_current_spawn_batch())
			spawn_passes += 1
			if get_active_enemies().size() >= get_current_density_cap():
				break
	_emit_survival_time()


func get_time_remaining() -> float:
	return _time_remaining


func get_current_density_cap() -> int:
	var progress := _timeline_progress()
	var cap := roundi(lerpf(
		float(base_density_cap),
		float(maxi(base_density_cap, maximum_density_cap)),
		pow(progress, 0.78)
	))
	if is_final_rush():
		cap += final_rush_density_bonus
	cap += roundi(float(_current_horde_density_bonus()) * _horde_intensity())
	cap += 12 * (_difficulty_tier - 1)
	return maxi(1, cap)


func get_current_alive_cap() -> int:
	return get_current_density_cap()


func get_current_normal_health_multiplier() -> float:
	var timeline_multiplier := lerpf(
		base_normal_health_multiplier,
		maxf(base_normal_health_multiplier, maximum_normal_health_multiplier),
		pow(_timeline_progress(), normal_health_curve_exponent)
	)
	return timeline_multiplier * (1.0 + 0.25 * float(_difficulty_tier - 1))


func get_current_enemy_damage_multiplier() -> float:
	return (
		lerpf(1.15, 2.20, pow(_timeline_progress(), 0.9))
		* (1.0 + 0.15 * float(_difficulty_tier - 1))
	)


func get_survival_elapsed() -> float:
	return _survival_elapsed


func is_horde_active() -> bool:
	return _horde_intensity() > 0.0


func get_horde_kind() -> StringName:
	if _post_boss_horde_remaining > 0.0:
		return &"post_boss"
	if _scheduled_horde_intensity() > 0.0:
		return &"scheduled"
	return &""


func get_current_experience_multiplier() -> float:
	match get_horde_kind():
		&"post_boss":
			return post_boss_experience_multiplier
		&"scheduled":
			return scheduled_horde_experience_multiplier
		_:
			return 1.0


func get_spawned_elite_count() -> int:
	return _spawned_elite_count


func get_spawned_boss_count() -> int:
	return _spawned_boss_count


func get_completion_boss_spawn_count() -> int:
	return _completion_boss_spawn_count


func get_elite_defeat_count() -> int:
	return _elite_defeat_count


func is_final_rush() -> bool:
	return (
		_running
		and _time_remaining > 0.0
		and _time_remaining <= minf(final_rush_duration, survival_duration)
	)


func is_exit_unlocked() -> bool:
	return _exit_unlocked


func _spawn_until_cap(maximum_new: int) -> void:
	var available := maxi(0, get_current_density_cap() - get_active_enemies().size())
	for _spawn_index in mini(maximum_new, available):
		var pool := _available_normal_pool()
		if pool.is_empty():
			return
		_spawn_survival_enemy(StringName(pool[_rng.randi_range(0, pool.size() - 1)]), false)


func _spawn_scheduled_events(previous_elapsed: float, current_elapsed: float) -> void:
	while _scheduled_elite_index < _elite_schedule.size():
		var event_time := maxf(0.0, _elite_schedule[_scheduled_elite_index])
		if event_time > current_elapsed:
			break
		_scheduled_elite_index += 1
		if event_time > previous_elapsed and event_time < survival_duration:
			_spawn_elite_wave(_strong_enemy_count_for_time(event_time))
	while _scheduled_boss_index < _boss_schedule.size():
		var event_time := maxf(0.0, _boss_schedule[_scheduled_boss_index])
		if event_time > current_elapsed:
			break
		_scheduled_boss_index += 1
		if event_time > previous_elapsed and event_time < survival_duration:
			_spawn_boss_wave(_boss_count_for_time(event_time))


func _spawn_final_rush_events(_previous_elapsed: float, current_elapsed: float) -> void:
	var rush_start := maxf(0.0, survival_duration - final_rush_duration)
	if not _final_rush_started and current_elapsed >= rush_start:
		_final_rush_started = true
		_next_final_rush_elite_time = rush_start
		_next_final_rush_boss_time = rush_start
	if not _final_rush_started:
		return
	while (
		_next_final_rush_elite_time <= current_elapsed
		and _next_final_rush_elite_time < survival_duration
	):
		_spawn_elite_wave(_final_rush_strong_count(_next_final_rush_elite_time - rush_start))
		_next_final_rush_elite_time += maxf(0.1, final_rush_elite_interval)
	while (
		_next_final_rush_boss_time <= current_elapsed
		and _next_final_rush_boss_time < survival_duration
	):
		_spawn_boss_wave(_final_rush_boss_count(_next_final_rush_boss_time - rush_start))
		_next_final_rush_boss_time += maxf(0.1, final_rush_boss_interval)


func _spawn_elite() -> void:
	_spawned_elite_count += 1
	var variant_index := (_spawned_elite_count - 1) % STRONG_ENEMY_VARIANTS.size()
	var archetype_id := STRONG_ENEMY_VARIANTS[variant_index]
	var elite := _spawn_survival_enemy(archetype_id, false)
	if elite != null:
		elite.set_meta("survival_role", "elite")
		elite.set_meta("strong_variant_id", String(archetype_id))
		if elite.has_method("apply_survival_health_multiplier"):
			elite.call(
				"apply_survival_health_multiplier",
				get_current_normal_health_multiplier() * 1.75
			)
		if elite is Node2D:
			(elite as Node2D).scale *= Vector2(1.16, 1.16)
		elite_spawned.emit(elite, _time_remaining)


func _spawn_boss(completion_boss: bool) -> void:
	_spawned_boss_count += 1
	if completion_boss:
		_completion_boss_spawn_count += 1
	var boss := _spawn_survival_enemy(&"guardian", true, completion_boss)
	if boss != null:
		var variant_id := STAGE_BOSS_VARIANTS[(_spawned_boss_count - 1) % STAGE_BOSS_VARIANTS.size()]
		boss.set_meta("boss_variant_id", String(variant_id))
		if boss.has_method("configure_survival_variant"):
			boss.call("configure_survival_variant", variant_id)
		if boss.has_method("apply_survival_health_multiplier"):
			boss.call(
				"apply_survival_health_multiplier",
				lerpf(1.0, 2.4, pow(_timeline_progress(), 0.8))
			)
		_apply_survival_damage_scale(boss)
		boss_spawned.emit(boss, completion_boss, _time_remaining)


func _spawn_completion_boss() -> void:
	if _completion_boss_spawn_count > 0:
		return
	_spawn_boss(true)


func _spawn_elite_wave(count: int) -> void:
	for _index in maxi(1, count):
		_spawn_elite()


func _spawn_boss_wave(count: int) -> void:
	for _index in maxi(1, count):
		_spawn_boss(false)


func _strong_enemy_count_for_time(event_time: float) -> int:
	return clampi(1 + floori(event_time / 120.0), 1, 5)


func _boss_count_for_time(event_time: float) -> int:
	if event_time < 300.0:
		return 1
	if event_time < 420.0:
		return 2
	if event_time < 480.0:
		return 3
	return 4


func _final_rush_strong_count(rush_elapsed: float) -> int:
	return clampi(3 + floori(maxf(0.0, rush_elapsed) / 10.0), 3, 5)


func _final_rush_boss_count(rush_elapsed: float) -> int:
	return clampi(2 + floori(maxf(0.0, rush_elapsed) / 15.0), 2, 3)


func _complete_survival() -> void:
	if _survival_completed:
		return
	_survival_completed = true
	_running = false
	_exit_unlocked = true
	for enemy in _active_enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()
	progress_changed.emit(0, get_current_density_cap())
	boss_stage_completed.emit()


func _timeline_progress() -> float:
	return clampf(_survival_elapsed / maxf(0.001, survival_duration), 0.0, 1.0)


func _current_spawn_interval() -> float:
	var interval := lerpf(
		base_spawn_interval,
		minf(base_spawn_interval, minimum_spawn_interval),
		pow(_timeline_progress(), 0.82)
	)
	if is_final_rush():
		interval *= final_rush_spawn_interval_multiplier
	var horde_intensity := _horde_intensity()
	if horde_intensity > 0.0:
		interval *= lerpf(1.0, _current_horde_interval_multiplier(), horde_intensity)
	return maxf(0.05, interval)


func _current_spawn_batch() -> int:
	var batch := roundi(lerpf(
		float(base_spawn_batch),
		float(maxi(base_spawn_batch, maximum_spawn_batch)),
		_timeline_progress()
	))
	if is_final_rush():
		batch += 2
	batch += roundi(float(_current_horde_batch_bonus()) * _horde_intensity())
	batch += 2 * (_difficulty_tier - 1)
	return maxi(1, batch)


func _scheduled_horde_intensity() -> float:
	var elapsed := _survival_elapsed - scheduled_horde_time
	if elapsed < 0.0 or elapsed >= scheduled_horde_duration:
		return 0.0
	var rise_duration := minf(0.5, scheduled_horde_duration * 0.15)
	var fade_duration := minf(2.0, scheduled_horde_duration * 0.3)
	if elapsed < rise_duration:
		return clampf(elapsed / maxf(0.01, rise_duration), 0.0, 1.0)
	var fade_start := scheduled_horde_duration - fade_duration
	if elapsed > fade_start:
		return clampf((scheduled_horde_duration - elapsed) / maxf(0.01, fade_duration), 0.0, 1.0)
	return 1.0


func _horde_intensity() -> float:
	if _post_boss_horde_remaining > 0.0:
		var fade_duration := minf(2.5, post_boss_horde_duration * 0.3)
		return clampf(_post_boss_horde_remaining / maxf(0.01, fade_duration), 0.0, 1.0)
	return _scheduled_horde_intensity()


func _current_horde_density_bonus() -> int:
	return post_boss_horde_density_bonus if get_horde_kind() == &"post_boss" else scheduled_horde_density_bonus


func _current_horde_batch_bonus() -> int:
	return post_boss_horde_batch_bonus if get_horde_kind() == &"post_boss" else scheduled_horde_batch_bonus


func _current_horde_interval_multiplier() -> float:
	return post_boss_horde_interval_multiplier if get_horde_kind() == &"post_boss" else scheduled_horde_interval_multiplier


func _available_normal_pool() -> Array[StringName]:
	var pool: Array[StringName] = []
	for archetype_variant in normal_enemy_unlocks:
		var archetype_id := StringName(archetype_variant)
		if _survival_elapsed >= maxf(0.0, float(normal_enemy_unlocks[archetype_variant])):
			pool.append(archetype_id)
	if pool.is_empty():
		pool.append(&"sprout")
	return pool


func _emit_survival_time() -> void:
	survival_time_changed.emit(
		_time_remaining,
		survival_duration,
		get_active_enemies().size(),
		get_current_density_cap(),
		is_final_rush()
	)


func _spawn_survival_enemy(
	archetype_id: StringName,
	is_boss: bool,
	completion_boss: bool = false
) -> Node:
	var packed := guardian_scene if is_boss else enemy_scene
	if packed == null:
		return null
	var enemy := packed.instantiate()
	add_child(enemy)
	enemy.set_meta("encounter_archetype_id", String(archetype_id))
	enemy.set_meta("persistent_pursuit", true)
	enemy.set_meta("completion_boss", completion_boss)
	if enemy is Node2D:
		var slot := _active_enemies.size()
		var side := -1.0 if (slot % 2 == 0) else 1.0
		var rank := floori(float(slot) / 10.0) % 3
		var lane := (slot % 5) - 2
		var local_spawn := Vector2(
			side * (190.0 + 92.0 * float(rank)),
			-18.0 * float(abs(lane))
		)
		if spawn_around_player:
			var player := get_tree().get_first_node_in_group("Player") as Node2D
			var anchor_x := player.global_position.x if player != null else global_position.x
			var can_spawn_left := anchor_x - spawn_perimeter_min >= spawn_route_left
			var can_spawn_right := anchor_x + spawn_perimeter_min <= spawn_route_right
			if can_spawn_left != can_spawn_right:
				side = -1.0 if can_spawn_left else 1.0
			var distance := _rng.randf_range(spawn_perimeter_min, spawn_perimeter_max)
			var spawn_x := clampf(
				anchor_x + side * distance,
				spawn_route_left,
				spawn_route_right
			)
			var global_spawn := Vector2(
				spawn_x,
				_get_floor_y(spawn_x) + 10.0 - 18.0 * float(abs(lane))
			)
			local_spawn = to_local(global_spawn)
		(enemy as Node2D).position = local_spawn
		_spawn_positions[enemy.get_instance_id()] = (enemy as Node2D).position
	if not is_boss and enemy.has_method("configure_archetype"):
		enemy.call("configure_archetype", archetype_id)
	if not is_boss and enemy.has_method("apply_survival_health_multiplier"):
		enemy.call(
			"apply_survival_health_multiplier",
			get_current_normal_health_multiplier()
		)
	_apply_survival_damage_scale(enemy)
	if enemy.has_signal("defeated"):
		enemy.connect(
			"defeated",
			_on_survival_enemy_defeated.bind(is_boss, completion_boss)
		)
	_active_enemies.append(enemy)
	return enemy


func _apply_survival_damage_scale(enemy: Node) -> void:
	if enemy == null:
		return
	var archetype_variant: Variant = enemy.get("archetype")
	if not archetype_variant is Resource:
		return
	var archetype_resource := archetype_variant as Resource
	var base_damage := maxi(1, int(archetype_resource.get("attack_damage")))
	var multiplier := get_current_enemy_damage_multiplier()
	archetype_resource.set("attack_damage", maxi(1, roundi(float(base_damage) * multiplier)))
	enemy.set_meta("survival_damage_multiplier", multiplier)


func _on_survival_enemy_defeated(
	enemy: Node,
	experience: int,
	gold: int,
	is_boss: bool,
	completion_boss: bool
) -> void:
	if not _active_enemies.has(enemy):
		return
	var reward_position := (enemy as Node2D).global_position if enemy is Node2D else global_position
	_active_enemies.erase(enemy)
	var archetype_id := StringName(enemy.get_meta("encounter_archetype_id", ""))
	var is_elite := String(enemy.get_meta("survival_role", "")) == "elite"
	var reward_role := &"boss" if is_boss else (&"elite" if is_elite else &"normal")
	if _running and not is_boss and _time_remaining > 0.0:
		_spawn_remaining = minf(_spawn_remaining, 0.05)
	if is_elite:
		_elite_defeat_count += 1
		elite_defeated.emit(reward_position)
	elif not is_boss:
		_try_spawn_survival_pickup(reward_position)
	_try_spawn_reward_bags(reward_position, reward_role, archetype_id, gold)
	if is_boss:
		if not completion_boss:
			_post_boss_horde_remaining = maxf(
				_post_boss_horde_remaining,
				post_boss_horde_duration
			)
			_spawn_remaining = 0.0
		boss_defeated.emit(reward_position, completion_boss)
	_gold += maxi(0, gold)
	if not completion_boss:
		_spawn_experience_burst(
			reward_position,
			maxi(1, roundi(float(experience) * get_current_experience_multiplier())),
			6 if is_elite or is_boss else 2
		)
	if is_boss and not completion_boss:
		_experience += maxi(0, experience)
	if completion_boss:
		_running = false
		_exit_unlocked = true
		boss_stage_completed.emit()
	progress_changed.emit(get_active_enemies().size(), get_current_density_cap())


func _recycle_distant_enemies() -> void:
	if not spawn_around_player:
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player == null:
		return
	for enemy in get_active_enemies():
		if not enemy is Node2D or String(enemy.get_meta("encounter_archetype_id", "")) == "guardian":
			continue
		if absf((enemy as Node2D).global_position.x - player.global_position.x) <= recycle_distance:
			continue
		var side := -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
		var can_spawn_left := player.global_position.x - spawn_perimeter_min >= spawn_route_left
		var can_spawn_right := player.global_position.x + spawn_perimeter_min <= spawn_route_right
		if can_spawn_left != can_spawn_right:
			side = -1.0 if can_spawn_left else 1.0
		var spawn_x := clampf(
			player.global_position.x
				+ side * _rng.randf_range(spawn_perimeter_min, spawn_perimeter_max),
			spawn_route_left,
			spawn_route_right
		)
		var spawn_position := Vector2(spawn_x, _get_floor_y(spawn_x) + 10.0)
		if enemy.has_method("reset_encounter"):
			enemy.call("reset_encounter", to_local(spawn_position))
		else:
			(enemy as Node2D).global_position = spawn_position


func _get_floor_y(world_x: float) -> float:
	var route := get_node_or_null("../GeneratedRoute")
	if route != null and route.has_method("get_floor_y_at"):
		return float(route.call("get_floor_y_at", world_x))
	return spawn_floor_y - 10.0


func _spawn_experience_gem(at_position: Vector2, value: int) -> void:
	if experience_gem_scene == null:
		return
	var gem := experience_gem_scene.instantiate()
	add_child(gem)
	if gem is Node2D:
		(gem as Node2D).global_position = at_position
	if gem.has_method("configure"):
		gem.call("configure", value, get_tree().get_first_node_in_group("Player") as Node2D)
	if gem.has_method("launch"):
		gem.call(
			"launch",
			Vector2(
				_rng.randf_range(-360.0, 360.0),
				_rng.randf_range(-300.0, -150.0)
			),
			_rng.randf_range(0.26, 0.42)
		)
	experience_gem_spawned.emit(gem, value)


func _spawn_experience_burst(
	at_position: Vector2,
	total_value: int,
	minimum_shards: int = 1
) -> void:
	var safe_minimum := maxi(1, minimum_shards)
	var distributed_total := maxi(1, total_value)
	var shard_count := clampi(
		distributed_total,
		mini(safe_minimum, distributed_total),
		12
	)
	var base_value := distributed_total / shard_count
	var remainder := distributed_total % shard_count
	for shard_index in shard_count:
		_spawn_experience_gem(
			at_position,
			base_value + (1 if shard_index < remainder else 0)
		)


func roll_survival_pickup(roll: float) -> StringName:
	var chance := clampf(normal_pickup_drop_chance, 0.0, 1.0)
	if chance <= 0.0 or roll < 0.0 or roll >= chance:
		return &""
	var weighted_roll := roll / chance
	if weighted_roll < 0.45:
		return &"healing_fruit"
	if weighted_roll < 0.70:
		return &"experience_magnet"
	return &"swift_fruit"


func get_monster_material(archetype_id: StringName) -> StringName:
	return StringName(MONSTER_MATERIALS.get(String(archetype_id), "autumn_wood"))


func roll_reward_bags(
	role: StringName,
	money_roll: float,
	material_roll: float,
	archetype_id: StringName,
	gold_reward: int
) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	var money_chance := normal_money_bag_chance
	if role == &"elite":
		money_chance = elite_money_bag_chance
	elif role == &"boss":
		money_chance = boss_money_bag_chance
	if money_roll >= 0.0 and money_roll < clampf(money_chance, 0.0, 1.0):
		var gold_amount := maxi(3, roundi(float(maxi(1, gold_reward)) * (
			1.0 if role != &"normal" else 0.5
		)))
		rewards.append({"kind": "money", "reward": {"gold": gold_amount}})
	var material_chance := normal_material_bag_chance
	if role == &"elite":
		material_chance = elite_material_bag_chance
	elif role == &"boss":
		material_chance = boss_material_bag_chance
	if material_roll >= 0.0 and material_roll < clampf(material_chance, 0.0, 1.0):
		var material_id := get_monster_material(archetype_id)
		var material_quantity := 1
		if role == &"elite":
			material_quantity = 2
		elif role == &"boss":
			material_quantity = 3
		rewards.append({
			"kind": "material",
			"reward": {String(material_id): material_quantity},
		})
	return rewards


func _try_spawn_reward_bags(
	at_position: Vector2,
	role: StringName,
	archetype_id: StringName,
	gold_reward: int
) -> void:
	var rewards := roll_reward_bags(
		role,
		_rng.randf(),
		_rng.randf(),
		archetype_id,
		gold_reward
	)
	for index in rewards.size():
		var bag := rewards[index]
		var kind := StringName(bag.get("kind", ""))
		var reward := (bag.get("reward", {}) as Dictionary).duplicate(true)
		var offset := Vector2(float(index * 34 - 17), -8.0)
		_spawn_survival_pickup(
			&"money_bag" if kind == &"money" else &"material_bag",
			at_position + offset,
			reward,
			kind
		)


func _try_spawn_survival_pickup(at_position: Vector2) -> Node:
	var item_id := roll_survival_pickup(_rng.randf())
	if item_id == &"":
		return null
	return _spawn_survival_pickup(item_id, at_position)


func _spawn_survival_pickup(
	item_id: StringName,
	at_position: Vector2,
	reward: Dictionary = {},
	reward_kind: StringName = &""
) -> Node:
	if survival_pickup_scene == null:
		return null
	var pickup := survival_pickup_scene.instantiate()
	add_child(pickup)
	if pickup is Node2D:
		(pickup as Node2D).global_position = at_position
	if pickup.has_method("configure"):
		pickup.call(
			"configure",
			item_id,
			get_tree().get_first_node_in_group("Player") as Node2D
		)
	if pickup.has_signal("collected"):
		if reward.is_empty():
			pickup.connect("collected", _on_survival_pickup_collected, CONNECT_ONE_SHOT)
		else:
			pickup.connect(
				"collected",
				_on_reward_bag_collected.bind(reward_kind, reward),
				CONNECT_ONE_SHOT
			)
	survival_pickup_spawned.emit(pickup, item_id)
	if not reward.is_empty():
		reward_bag_spawned.emit(pickup, reward_kind, reward.duplicate(true))
	return pickup


func _on_reward_bag_collected(
	_item_id: StringName,
	_collector: Node,
	kind: StringName,
	reward: Dictionary
) -> void:
	reward_bag_collected.emit(kind, reward.duplicate(true))


func _on_survival_pickup_collected(item_id: StringName, collector: Node) -> void:
	apply_survival_pickup(item_id, collector)
	survival_pickup_collected.emit(item_id)


func apply_survival_pickup(item_id: StringName, collector: Node) -> bool:
	if collector == null or not is_instance_valid(collector):
		return false
	match item_id:
		&"healing_fruit":
			if collector.has_method("restore_health"):
				collector.call("restore_health", 35)
				return true
		&"experience_magnet":
			for gem in get_tree().get_nodes_in_group("ExperienceGems"):
				if is_instance_valid(gem) and gem.has_method("collect"):
					gem.call("collect")
			return true
		&"swift_fruit":
			if collector.has_method("apply_temporary_move_speed"):
				collector.call("apply_temporary_move_speed", 1.4, 10.0)
				return true
	return false
