extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/combat/ThornBloomFieldController.tscn")
const THORN_BLOOM_PATH := "res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_bloom.png"
const THORN_SEED_PATH := "res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_seed.png"
const THORN_RUN_PATH := "res://assets/generated/vfx/skill_materials/components/base/thorn__thorn_run.png"

var _failures := 0
var _targets: Array = []


class TestTarget:
	extends CharacterBody2D

	var health := 500
	var damage_taken := 0
	var hit_count := 0


	func take_hit(raw_damage: int, _source_position: Vector2, _knockback: float = 0.0) -> int:
		var dealt := mini(health, maxi(0, raw_damage))
		health -= dealt
		damage_taken += dealt
		hit_count += 1
		return dealt


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill catalog must load.")
	var expected := {
		"ancient_roots_pursuit": ["荊棘", "破土", "開花", "荊棘刺"],
		"growth_ring_guard": ["荊棘", "依序開花", "周圍敵人", "連射"],
		"eternal_forest_manifest": ["荊棘花獄", "大量", "萬刺", "大師"],
	}
	for skill_id in expected:
		var skill := catalog.get_skill(skill_id)
		var description := String(skill.get("description", ""))
		for phrase in expected[skill_id]:
			_expect(description.contains(String(phrase)), "%s codex description must explain %s." % [skill_id, phrase])
		_expect(String(skill.get("gameplay_family", "")) == "blooming_thorn_barrage", "%s must use the Thorn barrage gameplay family." % skill_id)

	var field := CONTROLLER_SCENE.instantiate() as Node2D
	root.add_child(field)
	var near_a := TestTarget.new()
	near_a.position = Vector2(80.0, 0.0)
	root.add_child(near_a)
	var near_b := TestTarget.new()
	near_b.position = Vector2(-110.0, 0.0)
	root.add_child(near_b)
	var outside := TestTarget.new()
	outside.position = Vector2(330.0, 0.0)
	root.add_child(outside)
	_targets = [near_a, near_b, outside]
	_expect(bool(field.call("configure", Vector2.ZERO, Callable(self, "_provide_targets"), {
		"duration": 1.8,
		"radius": 210.0,
		"emerge_duration": 0.25,
		"bloom_delay": 0.35,
		"volley_interval": 0.30,
		"thorn_count": 6,
		"spikes_per_volley": 6,
		"damage_per_spike": 5,
		"knockback": 35.0,
		"tier_rank": 2,
	})), "Thorn field must accept one authored combat profile.")
	field.call("advance", 0.30)
	_expect(near_a.damage_taken == 0, "Thorns must visibly emerge and bloom before firing.")
	field.call("advance", 0.50)
	_expect(near_a.damage_taken > 0 and near_b.damage_taken > 0, "Bloomed thorns must fire spikes at surrounding enemies.")
	_expect(outside.damage_taken == 0, "Thorn spikes must respect the authored field radius.")
	var state := field.call("get_debug_state") as Dictionary
	_expect(int(state.get("volley_count", 0)) >= 1 and int(state.get("spike_hit_count", 0)) >= 2, "Thorn gameplay must expose real repeated spike volleys.")
	field.queue_free()
	near_a.queue_free()
	near_b.queue_free()
	outside.queue_free()
	await process_frame

	var effect_scene := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var previous_thorns := 0
	var previous_radius := 0.0
	for tier in range(1, 4):
		var effect := effect_scene.instantiate()
		root.add_child(effect)
		effect.call("play_series", "thorn", tier, 1, false, 1.0)
		var visual := effect.call("get_thorn_bloom_vfx_state") as Dictionary
		_expect(String(visual.get("renderer", "")) == "thorn_emerge_bloom_barrage", "Thorn needs a dedicated layered VFX renderer.")
		_expect((visual.get("layer_ids", []) as Array) == ["ground_cracks", "thorn_tendrils", "bloom_sequence", "spike_barrage", "petal_decay"], "Thorn VFX must preserve emerge, bloom, attack, and decay layers.")
		_expect(String(visual.get("vine_segment_texture", "")) == THORN_BLOOM_PATH, "Thorn vines must stack the supplied thorn_bloom raster.")
		_expect(String(visual.get("terminal_flower_texture", "")) == THORN_SEED_PATH, "Every Thorn vine must terminate in the supplied thorn_seed flower.")
		_expect(String(visual.get("scatter_projectile_texture", "")) == THORN_RUN_PATH, "Thorn barrages must use the supplied thorn_run raster.")
		var thorn_count := int(visual.get("thorn_count", 0))
		var radius := float(visual.get("radius", 0.0))
		_expect(thorn_count > previous_thorns and radius > previous_radius, "Thorn count and range must grow every tier.")
		_expect(
			int(visual.get("segments_per_vine", 0)) == [5, 7, 9][tier - 1],
			"Thorn tiers must grow denser 5/7/9-segment vines."
		)
		_expect(
			float(visual.get("segment_stride", INF)) < float(visual.get("nominal_segment_height", 0.0)) * 0.55,
			"Adjacent Thorn segments must overlap densely enough to read as one connected vine."
		)
		_expect(
			is_zero_approx(float(visual.get("root_offset_y", INF))),
			"The first Thorn segment must originate on the field's ground anchor."
		)
		_expect(
			float(visual.get("flower_offset_from_last_segment", INF)) <= float(visual.get("segment_stride", 0.0)),
			"The terminal flower must overlap the last vine segment instead of floating above it."
		)
		_expect(int(visual.get("vine_segment_count", 0)) == thorn_count * [5, 7, 9][tier - 1], "Every Thorn vine must expose its complete stacked segment count.")
		_expect(int(visual.get("terminal_flower_count", 0)) == thorn_count, "Every Thorn vine must grow exactly one terminal flower.")
		if tier == 3:
			_expect(thorn_count >= 10, "Master Thorn must grow at least ten vines.")
			_expect(int(visual.get("projectiles_per_vine", 0)) >= 20, "Every master Thorn vine must scatter about twenty thorn_run projectiles.")
			_expect(int(visual.get("scatter_projectile_count", 0)) >= thorn_count * 20, "Master Thorn needs a screen-filling scatter pool for all ten vines.")
			effect.call("debug_set_progress", 0.51)
			visual = effect.call("get_thorn_bloom_vfx_state") as Dictionary
			_expect(int(visual.get("active_terminal_flower_count", 0)) == thorn_count, "All terminal flowers must bloom before the master barrage.")
			_expect(int(visual.get("active_scatter_projectile_count", 0)) > 0, "Bloomed master flowers must visibly fire the scatter barrage.")
		previous_thorns = thorn_count
		previous_radius = radius
		effect.queue_free()
		await process_frame
	_finish()


func _provide_targets() -> Array:
	return _targets.duplicate()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Thorn series emerges, blooms, and fires scalable surrounding barrages")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
