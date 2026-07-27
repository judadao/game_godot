class_name SurvivalWaveDirector
extends EncounterDirector

signal phase_time_changed(phase: int, remaining: float, alive: int, cap: int)
signal boss_stage_completed
signal experience_gem_spawned(gem: Node, value: int)

@export var survival_phases: Array[Dictionary] = [
	{"duration": 40.0, "spawn_interval": 1.15, "spawn_batch": 2, "alive_cap": 14, "pool": [&"sprout", &"hopper", &"moth_swarm"]},
	{"duration": 42.0, "spawn_interval": 0.80, "spawn_batch": 3, "alive_cap": 22, "pool": [&"sprout", &"hopper", &"moth_swarm", &"thornling"]},
	{"duration": 45.0, "spawn_interval": 0.58, "spawn_batch": 3, "alive_cap": 32, "pool": [&"hopper", &"moth_swarm", &"thornling", &"charger", &"grove_shaman"]},
	{"duration": 48.0, "spawn_interval": 0.42, "spawn_batch": 4, "alive_cap": 44, "pool": [&"sprout", &"moth_swarm", &"thornling", &"charger", &"grove_shaman", &"elite"]},
	{"duration": -1.0, "spawn_interval": 0.72, "spawn_batch": 3, "alive_cap": 30, "pool": [&"moth_swarm", &"thornling", &"charger", &"grove_shaman"]},
]
@export var experience_gem_scene: PackedScene = preload("res://scenes/combat/ExperienceGem.tscn")

var _phase_remaining := 0.0
var _spawn_remaining := 0.0
var _guardian_spawn_count := 0
var _exit_unlocked := false


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
	_begin_phase()
	encounter_started.emit(survival_phases.size())
	return true


func advance_survival(delta: float) -> void:
	if not _running or survival_phases.is_empty():
		return
	var phase := survival_phases[_wave_index]
	var duration := float(phase.get("duration", -1.0))
	if duration > 0.0:
		_phase_remaining = maxf(0.0, _phase_remaining - maxf(0.0, delta))
		if _phase_remaining <= 0.0:
			_wave_index = mini(_wave_index + 1, survival_phases.size() - 1)
			_begin_phase()
			return
	_spawn_remaining -= maxf(0.0, delta)
	if _spawn_remaining <= 0.0:
		_spawn_remaining = maxf(0.05, float(phase.get("spawn_interval", 1.0)))
		_spawn_until_cap(maxi(1, int(phase.get("spawn_batch", 1))))
	phase_time_changed.emit(get_wave_number(), _phase_remaining, get_active_enemies().size(), get_current_alive_cap())


func get_phase_remaining() -> float:
	return _phase_remaining


func get_current_alive_cap() -> int:
	if survival_phases.is_empty() or _wave_index < 0:
		return 0
	return maxi(1, int(survival_phases[_wave_index].get("alive_cap", 1)))


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
	_spawn_until_cap(mini(maxi(6, int(phase.get("spawn_batch", 1)) * 2), get_current_alive_cap()))
	wave_started.emit(get_wave_number(), survival_phases.size(), get_active_enemies().size())
	progress_changed.emit(get_active_enemies().size(), get_current_alive_cap())


func _spawn_until_cap(maximum_new: int) -> void:
	var available := maxi(0, get_current_alive_cap() - get_active_enemies().size())
	for _spawn_index in mini(maximum_new, available):
		var pool := survival_phases[_wave_index].get("pool", []) as Array
		if pool.is_empty():
			return
		_spawn_survival_enemy(StringName(pool[randi() % pool.size()]), false)


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
	if enemy is Node2D:
		var slot := _active_enemies.size()
		var side := -1.0 if (slot % 2 == 0) else 1.0
		var rank := floori(float(slot) / 10.0) % 3
		var lane := (slot % 5) - 2
		(enemy as Node2D).position = Vector2(
			side * (190.0 + 92.0 * float(rank)),
			-18.0 * float(abs(lane))
		)
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
	_gold += maxi(0, gold)
	if not is_guardian:
		_spawn_experience_gem(reward_position, maxi(1, experience))
	if is_guardian:
		_running = false
		_exit_unlocked = true
		boss_stage_completed.emit()
	progress_changed.emit(get_active_enemies().size(), get_current_alive_cap())


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
