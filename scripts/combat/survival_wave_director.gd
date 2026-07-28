class_name SurvivalWaveDirector
extends EncounterDirector

signal phase_time_changed(phase: int, remaining: float, alive: int, cap: int)
signal boss_stage_completed
signal experience_gem_spawned(gem: Node, value: int)

@export var survival_phases: Array[Dictionary] = [
	{"duration": 40.0, "spawn_interval": 1.15, "spawn_batch": 2, "density_cap": 14, "pool": [&"sprout", &"hopper", &"moth_swarm"]},
	{"duration": 42.0, "spawn_interval": 0.80, "spawn_batch": 3, "density_cap": 22, "pool": [&"sprout", &"hopper", &"moth_swarm", &"thornling"]},
	{"duration": 45.0, "spawn_interval": 0.58, "spawn_batch": 3, "density_cap": 32, "pool": [&"hopper", &"moth_swarm", &"thornling", &"charger", &"grove_shaman"]},
	{"duration": 48.0, "spawn_interval": 0.42, "spawn_batch": 4, "density_cap": 44, "pool": [&"sprout", &"moth_swarm", &"thornling", &"charger", &"grove_shaman", &"elite"]},
	{"duration": -1.0, "spawn_interval": 0.72, "spawn_batch": 3, "density_cap": 30, "pool": [&"moth_swarm", &"thornling", &"charger", &"grove_shaman"]},
]
@export var experience_gem_scene: PackedScene = preload("res://scenes/combat/ExperienceGem.tscn")
@export var spawn_around_player := false
@export var spawn_route_left := 0.0
@export var spawn_route_right := 0.0
@export var spawn_floor_y := 470.0
@export var spawn_perimeter_min := 720.0
@export var spawn_perimeter_max := 1040.0
@export var recycle_distance := 1500.0
@export var recycle_interval := 0.5

var _phase_remaining := 0.0
var _spawn_remaining := 0.0
var _recycle_remaining := 0.0
var _survival_elapsed := 0.0
var _guardian_spawn_count := 0
var _exit_unlocked := false
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	super._process(delta)
	if _running and not get_tree().paused:
		advance_survival(delta)


func start_encounter() -> bool:
	if _running or survival_phases.is_empty():
		return false
	_running = true
	_wave_index = 0
	_experience = 0
	_gold = 0
	_guardian_spawn_count = 0
	_exit_unlocked = false
	_survival_elapsed = 0.0
	_recycle_remaining = 0.0
	_rng.seed = int(Time.get_ticks_usec() ^ get_instance_id())
	_begin_phase()
	encounter_started.emit(survival_phases.size())
	return true


func advance_survival(delta: float) -> void:
	if not _running or survival_phases.is_empty():
		return
	var safe_delta := maxf(0.0, delta)
	_survival_elapsed += safe_delta
	_recycle_remaining -= safe_delta
	if _recycle_remaining <= 0.0:
		_recycle_remaining = maxf(0.1, recycle_interval)
		_recycle_distant_enemies()
	var phase := survival_phases[_wave_index]
	var duration := float(phase.get("duration", -1.0))
	if duration > 0.0:
		_phase_remaining = maxf(0.0, _phase_remaining - safe_delta)
		if _phase_remaining <= 0.0:
			_wave_index = mini(_wave_index + 1, survival_phases.size() - 1)
			_begin_phase()
			return
	_spawn_remaining -= safe_delta
	if _spawn_remaining <= 0.0:
		_spawn_remaining = maxf(0.05, float(phase.get("spawn_interval", 1.0)))
		_spawn_until_cap(maxi(1, int(phase.get("spawn_batch", 1))))
	phase_time_changed.emit(get_wave_number(), _phase_remaining, get_active_enemies().size(), get_current_density_cap())


func get_phase_remaining() -> float:
	return _phase_remaining


func get_current_density_cap() -> int:
	if survival_phases.is_empty() or _wave_index < 0:
		return 0
	return maxi(1, int(survival_phases[_wave_index].get("density_cap", 1)))


func get_current_alive_cap() -> int:
	return get_current_density_cap()


func get_survival_elapsed() -> float:
	return _survival_elapsed


func get_guardian_spawn_count() -> int:
	return _guardian_spawn_count


func is_exit_unlocked() -> bool:
	return _exit_unlocked


func _begin_phase() -> void:
	var phase := survival_phases[_wave_index]
	_phase_remaining = float(phase.get("duration", -1.0))
	_spawn_remaining = 0.0
	_engaged = false
	_disengage_remaining = -1.0
	if _wave_index == survival_phases.size() - 1:
		_spawn_guardian()
	_spawn_until_cap(mini(maxi(6, int(phase.get("spawn_batch", 1)) * 2), get_current_density_cap()))
	wave_started.emit(get_wave_number(), survival_phases.size(), get_active_enemies().size())
	progress_changed.emit(get_active_enemies().size(), get_current_density_cap())


func _spawn_until_cap(maximum_new: int) -> void:
	var available := maxi(0, get_current_density_cap() - get_active_enemies().size())
	for _spawn_index in mini(maximum_new, available):
		var pool := survival_phases[_wave_index].get("pool", []) as Array
		if pool.is_empty():
			return
		_spawn_survival_enemy(StringName(pool[_rng.randi_range(0, pool.size() - 1)]), false)


func _spawn_guardian() -> void:
	if _guardian_spawn_count > 0:
		return
	_guardian_spawn_count += 1
	_spawn_survival_enemy(&"guardian", true)


func _spawn_survival_enemy(archetype_id: StringName, is_guardian: bool) -> void:
	var packed := guardian_scene if is_guardian else enemy_scene
	if packed == null:
		return
	var enemy := packed.instantiate()
	add_child(enemy)
	enemy.set_meta("encounter_archetype_id", String(archetype_id))
	enemy.set_meta("persistent_pursuit", true)
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
	if not is_guardian and enemy.has_method("configure_archetype"):
		enemy.call("configure_archetype", archetype_id)
	if enemy.has_signal("defeated"):
		enemy.connect("defeated", _on_survival_enemy_defeated.bind(is_guardian))
	_active_enemies.append(enemy)


func _on_survival_enemy_defeated(enemy: Node, experience: int, gold: int, is_guardian: bool) -> void:
	if not _active_enemies.has(enemy):
		return
	var reward_position := (enemy as Node2D).global_position if enemy is Node2D else global_position
	_active_enemies.erase(enemy)
	if String(enemy.get_meta("encounter_archetype_id", "")) == "elite":
		elite_defeated.emit(reward_position)
	_gold += maxi(0, gold)
	if not is_guardian:
		_spawn_experience_gem(reward_position, maxi(1, experience))
	if is_guardian:
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
	experience_gem_spawned.emit(gem, value)
