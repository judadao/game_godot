class_name EncounterDirector
extends Node2D

signal encounter_started(total_waves: int)
signal wave_started(wave_number: int, total_waves: int, enemy_count: int)
signal progress_changed(remaining: int, total: int)
signal encounter_cleared(experience: int, gold: int)
signal combat_engaged
signal disengage_warning(seconds: int)
signal disengage_cancelled
signal combat_reset
signal elite_defeated(world_position: Vector2)

@export var enemy_scene: PackedScene = preload("res://scenes/monsters/AutumnEnemy.tscn")
@export var guardian_scene: PackedScene = preload("res://scenes/monsters/AutumnGuardian.tscn")
@export var wave_plan: Array[Dictionary] = []
@export var auto_start := false
@export var engage_radius := 650.0
@export var leash_radius := 760.0
@export var disengage_duration := 5.0

var _active_enemies: Array[Node] = []
var _wave_index := -1
var _wave_total := 0
var _experience := 0
var _gold := 0
var _running := false
var _engaged := false
var _disengage_remaining := -1.0
var _spawn_positions: Dictionary = {}


func _ready() -> void:
	if wave_plan.is_empty():
		wave_plan = build_autumn_run_plan()
	if auto_start:
		start_encounter()


func _process(delta: float) -> void:
	if not _running or _active_enemies.is_empty():
		return
	var player := get_tree().get_first_node_in_group("Player") as Node2D
	if player != null and is_instance_valid(player):
		update_engagement(player.global_position, delta)


func build_autumn_run_plan() -> Array[Dictionary]:
	return [
		{"enemies": [
			{"archetype": &"sprout", "position": Vector2(0, 0)},
			{"archetype": &"hopper", "position": Vector2(220, 0)},
		]},
		{"enemies": [
			{"archetype": &"thornling", "position": Vector2(0, 0)},
		]},
		{"enemies": [
			{"archetype": &"charger", "position": Vector2(130, 0)},
		]},
		{"enemies": [
			{"archetype": &"elite", "position": Vector2(130, 0)},
		]},
		{"enemies": [
			{"archetype": &"guardian", "position": Vector2(130, 0)},
		]},
	]


func start_encounter() -> bool:
	if _running or wave_plan.is_empty():
		return false
	_running = true
	_wave_index = -1
	_experience = 0
	_gold = 0
	encounter_started.emit(wave_plan.size())
	_spawn_next_wave()
	return true


func get_wave_number() -> int:
	return _wave_index + 1


func get_active_enemies() -> Array[Node]:
	var valid_enemies: Array[Node] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	return valid_enemies


func is_engaged() -> bool:
	return _engaged


func get_disengage_remaining() -> float:
	return _disengage_remaining


func update_engagement(player_position: Vector2, delta: float) -> void:
	if not _running or _active_enemies.is_empty():
		return
	var distance := global_position.distance_to(player_position)
	if not _engaged:
		if distance <= engage_radius:
			_engaged = true
			_disengage_remaining = -1.0
			combat_engaged.emit()
		return
	if distance <= leash_radius:
		if _disengage_remaining >= 0.0:
			_disengage_remaining = -1.0
			disengage_cancelled.emit()
		return
	if _disengage_remaining < 0.0:
		_disengage_remaining = disengage_duration
	else:
		_disengage_remaining -= maxf(0.0, delta)
	disengage_warning.emit(maxi(1, int(ceil(_disengage_remaining))))
	if _disengage_remaining <= 0.0:
		_reset_active_wave()


func _spawn_next_wave() -> void:
	_wave_index += 1
	if _wave_index >= wave_plan.size():
		_running = false
		encounter_cleared.emit(_experience, _gold)
		return

	var entries := wave_plan[_wave_index].get("enemies", []) as Array
	_wave_total = entries.size()
	_engaged = false
	_disengage_remaining = -1.0
	_spawn_positions.clear()
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var archetype_id := entry.get("archetype", &"sprout") as StringName
		var packed := guardian_scene if archetype_id == &"guardian" else enemy_scene
		if packed == null:
			continue
		var enemy := packed.instantiate()
		add_child(enemy)
		enemy.set_meta("encounter_archetype_id", String(archetype_id))
		if enemy is Node2D:
			(enemy as Node2D).position = entry.get("position", Vector2.ZERO) as Vector2
			_spawn_positions[enemy.get_instance_id()] = (enemy as Node2D).position
		if archetype_id != &"guardian" and enemy.has_method("configure_archetype"):
			enemy.call("configure_archetype", archetype_id)
		if enemy.has_signal("defeated"):
			enemy.connect("defeated", _on_enemy_defeated)
		_active_enemies.append(enemy)

	wave_started.emit(_wave_index + 1, wave_plan.size(), _active_enemies.size())
	progress_changed.emit(_active_enemies.size(), _wave_total)
	if _active_enemies.is_empty():
		call_deferred("_advance_or_clear")


func _on_enemy_defeated(enemy: Node, experience: int, gold: int) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	if String(enemy.get_meta("encounter_archetype_id", "")) == "elite":
		var reward_position := (
			(enemy as Node2D).global_position
			if enemy is Node2D
			else global_position
		)
		elite_defeated.emit(reward_position)
	_experience += maxi(0, experience)
	_gold += maxi(0, gold)
	progress_changed.emit(_active_enemies.size(), _wave_total)
	if _active_enemies.is_empty():
		call_deferred("_advance_or_clear")


func _advance_or_clear() -> void:
	if not _running or not _active_enemies.is_empty():
		return
	_spawn_next_wave()


func _reset_active_wave() -> void:
	for enemy in _active_enemies:
		if not is_instance_valid(enemy):
			continue
		var spawn_position := _spawn_positions.get(enemy.get_instance_id(), Vector2.ZERO) as Vector2
		if enemy.has_method("reset_encounter"):
			enemy.call("reset_encounter", spawn_position)
		elif enemy is Node2D:
			(enemy as Node2D).position = spawn_position
	_engaged = false
	_disengage_remaining = -1.0
	combat_reset.emit()
