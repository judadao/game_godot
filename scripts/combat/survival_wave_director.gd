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
signal boss_stage_completed
signal experience_gem_spawned(gem: Node, value: int)
signal survival_pickup_spawned(pickup: Node, item_id: StringName)
signal survival_pickup_collected(item_id: StringName)

@export_range(30.0, 1800.0, 1.0) var survival_duration := 600.0
@export_range(10.0, 120.0, 1.0) var final_rush_duration := 60.0
@export var scheduled_elite_times: Array[float] = [
	90.0, 180.0, 270.0, 360.0, 450.0,
]
@export var scheduled_boss_times: Array[float] = [300.0, 480.0]
@export_range(2.0, 60.0, 0.5) var final_rush_elite_interval := 15.0
@export_range(5.0, 60.0, 0.5) var final_rush_boss_interval := 30.0
@export_range(1, 120, 1) var base_density_cap := 30
@export_range(1, 160, 1) var maximum_density_cap := 120
@export_range(0, 80, 1) var final_rush_density_bonus := 40
@export_range(0.05, 5.0, 0.05) var base_spawn_interval := 0.55
@export_range(0.05, 5.0, 0.01) var minimum_spawn_interval := 0.12
@export_range(0.1, 1.0, 0.05) var final_rush_spawn_interval_multiplier := 0.5
@export_range(1, 16, 1) var base_spawn_batch := 5
@export_range(1, 20, 1) var maximum_spawn_batch := 12
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
@export_range(0.0, 1.0, 0.005) var normal_pickup_drop_chance := 0.08
@export var spawn_around_player := false
@export var spawn_route_left := 0.0
@export var spawn_route_right := 0.0
@export var spawn_floor_y := 470.0
@export var spawn_perimeter_min := 720.0
@export var spawn_perimeter_max := 1040.0
@export var recycle_distance := 1500.0
@export var recycle_interval := 0.5

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
var _rng := RandomNumberGenerator.new()


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
	_survival_elapsed = 0.0
	_time_remaining = survival_duration
	_spawn_remaining = 0.0
	_recycle_remaining = 0.0
	_engaged = false
	_disengage_remaining = -1.0
	_spawn_positions.clear()
	_rng.seed = int(Time.get_ticks_usec() ^ get_instance_id())
	_spawn_until_cap(mini(16, get_current_density_cap()))
	encounter_started.emit(1)
	_emit_survival_time()
	return true


func advance_survival(delta: float) -> void:
	if not _running:
		return
	var safe_delta := maxf(0.0, delta)
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
		_spawn_completion_boss()
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
	return maxi(1, cap)


func get_current_alive_cap() -> int:
	return get_current_density_cap()


func get_survival_elapsed() -> float:
	return _survival_elapsed


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
			_spawn_elite()
	while _scheduled_boss_index < _boss_schedule.size():
		var event_time := maxf(0.0, _boss_schedule[_scheduled_boss_index])
		if event_time > current_elapsed:
			break
		_scheduled_boss_index += 1
		if event_time > previous_elapsed and event_time < survival_duration:
			_spawn_boss(false)


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
		_spawn_elite()
		_next_final_rush_elite_time += maxf(0.1, final_rush_elite_interval)
	while (
		_next_final_rush_boss_time <= current_elapsed
		and _next_final_rush_boss_time < survival_duration
	):
		_spawn_boss(false)
		_next_final_rush_boss_time += maxf(0.1, final_rush_boss_interval)


func _spawn_elite() -> void:
	_spawned_elite_count += 1
	var elite := _spawn_survival_enemy(&"elite", false)
	if elite != null:
		elite_spawned.emit(elite, _time_remaining)


func _spawn_boss(completion_boss: bool) -> void:
	_spawned_boss_count += 1
	if completion_boss:
		_completion_boss_spawn_count += 1
	var boss := _spawn_survival_enemy(&"guardian", true, completion_boss)
	if boss != null:
		boss_spawned.emit(boss, completion_boss, _time_remaining)


func _spawn_completion_boss() -> void:
	if _completion_boss_spawn_count > 0:
		return
	_spawn_boss(true)


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
	return maxf(0.05, interval)


func _current_spawn_batch() -> int:
	var batch := roundi(lerpf(
		float(base_spawn_batch),
		float(maxi(base_spawn_batch, maximum_spawn_batch)),
		_timeline_progress()
	))
	if is_final_rush():
		batch += 2
	return maxi(1, batch)


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
	if enemy.has_signal("defeated"):
		enemy.connect(
			"defeated",
			_on_survival_enemy_defeated.bind(is_boss, completion_boss)
		)
	_active_enemies.append(enemy)
	return enemy


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
	if String(enemy.get_meta("encounter_archetype_id", "")) == "elite":
		_elite_defeat_count += 1
		elite_defeated.emit(reward_position)
	elif not is_boss:
		_try_spawn_survival_pickup(reward_position)
	_gold += maxi(0, gold)
	if not completion_boss:
		_spawn_experience_gem(reward_position, maxi(1, experience))
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
				_rng.randf_range(-160.0, 160.0),
				_rng.randf_range(-210.0, -120.0)
			),
			_rng.randf_range(0.2, 0.34)
		)
	experience_gem_spawned.emit(gem, value)


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


func _try_spawn_survival_pickup(at_position: Vector2) -> Node:
	var item_id := roll_survival_pickup(_rng.randf())
	if item_id == &"":
		return null
	return _spawn_survival_pickup(item_id, at_position)


func _spawn_survival_pickup(item_id: StringName, at_position: Vector2) -> Node:
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
		pickup.connect("collected", _on_survival_pickup_collected, CONNECT_ONE_SHOT)
	survival_pickup_spawned.emit(pickup, item_id)
	return pickup


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
