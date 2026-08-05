class_name RegionalBossDirector
extends EncounterDirector

signal boss_spawned(boss: Node, completion_boss: bool, remaining: float)
signal boss_defeated(world_position: Vector2, completion_boss: bool)
signal boss_stage_completed

@export var expedition_variant_id: StringName = &"autumn"
@export_range(1.0, 8.0, 0.1) var boss_health_multiplier := 1.0

var _completion_emitted := false
var _difficulty_tier := 1


func configure_difficulty_tier(tier: int) -> void:
	_difficulty_tier = clampi(tier, 1, 4)


func _ready() -> void:
	wave_plan = [{"enemies": [{"archetype": &"guardian", "position": Vector2.ZERO}]}]
	super._ready()


func start_encounter() -> bool:
	_completion_emitted = false
	var started := super.start_encounter()
	if not started:
		return false
	for enemy in get_active_enemies():
		enemy.set_meta("completion_boss", true)
		enemy.set_meta("expedition_variant_id", String(expedition_variant_id))
		var damage_multiplier := 1.0 + 0.15 * float(_difficulty_tier - 1)
		enemy.set_meta("expedition_damage_multiplier", damage_multiplier)
		if enemy.has_method("apply_survival_health_multiplier"):
			enemy.call(
				"apply_survival_health_multiplier",
				boss_health_multiplier * (1.0 + 0.25 * float(_difficulty_tier - 1))
			)
		var archetype_variant: Variant = enemy.get("archetype")
		if archetype_variant is Resource:
			var archetype_resource := archetype_variant as Resource
			archetype_resource.set(
				"attack_damage",
				maxi(
					1,
					roundi(float(archetype_resource.get("attack_damage")) * damage_multiplier)
				)
			)
		if enemy.has_signal("defeated"):
			enemy.connect("defeated", _on_boss_enemy_defeated, CONNECT_ONE_SHOT)
		boss_spawned.emit(enemy, true, 0.0)
	return true


func _on_boss_enemy_defeated(enemy: Node, _experience: int, _gold: int) -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	var world_position := (enemy as Node2D).global_position if enemy is Node2D else global_position
	boss_defeated.emit(world_position, true)
	call_deferred("_emit_stage_completed")


func _emit_stage_completed() -> void:
	boss_stage_completed.emit()
