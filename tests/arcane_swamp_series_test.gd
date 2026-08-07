extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/ArcaneSwampFieldController.tscn")

var _failures := 0
var _targets: Array = []


class TestTarget:
	extends CharacterBody2D

	var damage_taken := 0
	var statuses: Dictionary = {}


	func take_hit(raw_damage: int, _source: Vector2, _knockback: float = 0.0) -> int:
		damage_taken += maxi(0, raw_damage)
		return maxi(0, raw_damage)


	func apply_status(status_id: String, effect: Dictionary) -> void:
		statuses[status_id] = effect.duplicate(true)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller := CONTROLLER_SCENE.instantiate() as Node2D
	root.add_child(controller)
	for index in 12:
		var target := TestTarget.new()
		target.position = Vector2.from_angle(TAU * float(index) / 12.0) * (80.0 + index * 4.0)
		target.velocity = Vector2(120.0, -30.0)
		root.add_child(target)
		_targets.append(target)
	_expect(bool(controller.call("configure", Vector2.ZERO, Callable(self, "_provide_targets"), {
		"duration": 2.0, "radius": 260.0, "tick_interval": 0.25,
		"damage_per_tick": 4, "target_limit": 10, "tier_rank": 1,
	})), "Arcane Swamp must accept its gameplay profile.")
	controller.call("advance", 0.30)
	var rooted := 0
	for target_variant in _targets:
		var target := target_variant as TestTarget
		if target.statuses.has("arcane_swamp_entangled"):
			rooted += 1
			_expect(target.velocity.is_zero_approx(), "Entangled enemies must stop moving while held by the tentacles.")
			_expect(target.damage_taken >= 4, "Entangled enemies must take continuing damage.")
	_expect(rooted == 10, "Basic Arcane Swamp must entangle exactly up to ten enemies.")
	var state := controller.call("get_debug_state") as Dictionary
	_expect(int(state.get("target_limit", 0)) == 10 and int(state.get("entangled_count", 0)) == 10, "Arcane Swamp diagnostics must expose its ten-target basic contract.")
	controller.queue_free()
	for target in _targets:
		(target as Node).queue_free()
	await process_frame

	var effect_scene := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var previous_limit := 0
	var previous_layers := 0
	for tier in range(1, 4):
		var effect := effect_scene.instantiate()
		root.add_child(effect)
		effect.call("play_series", "arcane_swamp", tier, 1, false, 1.0)
		var visual := effect.call("get_arcane_swamp_vfx_state") as Dictionary
		_expect(String(visual.get("renderer", "")) == "blessing_mutable_arcane_swamp", "Arcane Swamp needs a dedicated mutable VFX renderer.")
		_expect((visual.get("layer_ids", []) as Array) == ["swamp_surface", "arcane_runes", "tentacle_body", "binding_coils", "damage_pulses"], "Arcane Swamp must visibly separate ground, restraint, and damage layers.")
		_expect(bool(visual.get("blessing_mutable", false)), "Arcane Swamp colors, materials, pulses, and tentacle density must remain Blessing-mutable.")
		var limit := int(visual.get("target_limit", 0))
		var layers := int(visual.get("real_visual_layer_count", 0))
		_expect(limit > previous_limit and layers > previous_layers, "Arcane Swamp target capacity and VFX density must grow every tier.")
		previous_limit = limit
		previous_layers = layers
		effect.queue_free()
		await process_frame
	_finish()


func _provide_targets() -> Array:
	return _targets.duplicate()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Arcane Swamp entangles ten-plus enemies with mutable layered VFX")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
