extends SceneTree

const ARCHETYPE_SCRIPT := "res://scripts/monsters/enemy_archetype.gd"
const ENEMY_SCENE := "res://scenes/monsters/AutumnEnemy.tscn"
const GUARDIAN_SCENE := "res://scenes/monsters/AutumnGuardian.tscn"
const DIRECTOR_SCRIPT := "res://scripts/combat/encounter_director.gd"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_archetype_catalog()
	await _test_enemy_and_elite_contract()
	await _test_encounter_director()
	await _test_guardian_contract()
	quit(0 if _failures == 0 else 1)


func _test_archetype_catalog() -> void:
	var script := load(ARCHETYPE_SCRIPT) as GDScript
	_expect(script != null, "EnemyArchetype script must load.")
	if script == null:
		return

	var catalog: Dictionary = script.call("autumn_catalog")
	var expected_ids := [&"sprout", &"hopper", &"thornling", &"charger", &"elite"]
	_expect(catalog.size() == 5, "Autumn catalog must contain exactly five archetypes.")
	for archetype_id in expected_ids:
		_expect(catalog.has(archetype_id), "Autumn catalog is missing '%s'." % archetype_id)
		if not catalog.has(archetype_id):
			continue
		var archetype: Resource = catalog[archetype_id]
		_expect(int(archetype.get("max_health")) > 0, "%s must have health." % archetype_id)
		_expect(float(archetype.get("speed")) > 0.0, "%s must have movement speed." % archetype_id)
		_expect(
			not (archetype.get("attack_patterns") as Array).is_empty(),
			"%s must expose at least one attack pattern." % archetype_id
		)
	_expect(
		(catalog[&"elite"].get("attack_patterns") as Array) == [&"cleave", &"shockwave"],
		"Elite must expose cleave and shockwave patterns."
	)
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Early-game balance test must load the card catalog.")
	var ember := database.get_card("ember_bolt")
	var ember_damage := int((ember.get("effect", {}) as Dictionary).get("amount", 0))
	for early_id in [&"sprout", &"hopper"]:
		var early_enemy := catalog[early_id] as EnemyArchetype
		var damage_after_defense := maxi(1, ember_damage - early_enemy.defense)
		_expect(
			ceili(float(early_enemy.max_health) / float(damage_after_defense)) <= 2,
			"%s must die within two default Ember Bolt hits." % early_id
		)
	_expect(
		int((catalog[&"sprout"] as EnemyArchetype).experience_reward)
			+ int((catalog[&"hopper"] as EnemyArchetype).experience_reward)
			>= 30,
		"The first two enemy types must fund the first fast level-up."
	)


func _test_enemy_and_elite_contract() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	_expect(packed != null, "AutumnEnemy scene must load.")
	if packed == null:
		return

	var enemy := packed.instantiate()
	root.add_child(enemy)
	await process_frame
	_expect(enemy.is_in_group("Enemies"), "AutumnEnemy must be discoverable as an enemy.")
	_expect(enemy.call("configure_archetype", &"sprout"), "Enemy must accept a known archetype.")
	_expect(not enemy.call("configure_archetype", &"unknown"), "Enemy must reject an unknown archetype.")

	var health_before := int(enemy.get("health"))
	var applied := int(enemy.call("take_hit", 12, Vector2.ZERO, 0.0))
	_expect(applied == 12, "The early Sprout must take the full 12 raw test damage.")
	_expect(int(enemy.get("health")) == health_before - 12, "Enemy damage must reduce health.")

	_expect(enemy.call("configure_archetype", &"elite"), "Enemy must configure the elite archetype.")
	var first_pattern: StringName = enemy.call("perform_next_attack")
	var second_pattern: StringName = enemy.call("perform_next_attack")
	_expect(first_pattern == &"cleave", "Elite first attack must be cleave.")
	_expect(second_pattern == &"shockwave", "Elite second attack must be shockwave.")

	enemy.queue_free()
	await process_frame


func _test_encounter_director() -> void:
	var director_script := load(DIRECTOR_SCRIPT) as GDScript
	var enemy_scene := load(ENEMY_SCENE) as PackedScene
	_expect(director_script != null, "EncounterDirector script must load.")
	if director_script == null or enemy_scene == null:
		return

	var director := director_script.new() as Node2D
	director.set("enemy_scene", enemy_scene)
	var custom_plan: Array[Dictionary] = [
		{"enemies": [
			{"archetype": &"sprout", "position": Vector2(10, 20)},
			{"archetype": &"hopper", "position": Vector2(30, 20)},
		]},
		{"enemies": [
			{"archetype": &"elite", "position": Vector2(50, 20)},
		]},
	]
	director.set("wave_plan", custom_plan)
	root.add_child(director)
	await process_frame

	var run_plan: Array = director.call("build_autumn_run_plan")
	_expect(run_plan.size() == 5, "Default autumn run must contain three normal waves, an elite wave, and a boss wave.")
	_expect(
		(run_plan[4]["enemies"] as Array)[0]["archetype"] == &"guardian",
		"Default autumn run must end with the guardian."
	)
	var cleared_rewards: Array[Vector2i] = []
	director.connect("encounter_cleared", func(experience: int, gold: int) -> void:
		cleared_rewards.append(Vector2i(experience, gold))
	)
	director.call("start_encounter")
	_expect(int(director.call("get_wave_number")) == 1, "Director must start at wave one.")
	_expect((director.call("get_active_enemies") as Array).size() == 2, "Wave one must spawn two enemies.")
	for enemy in (director.call("get_active_enemies") as Array).duplicate():
		enemy.call("take_hit", 9999, Vector2.ZERO, 0.0)
	await process_frame
	await process_frame
	_expect(int(director.call("get_wave_number")) == 2, "Clearing wave one must advance to wave two.")
	_expect((director.call("get_active_enemies") as Array).size() == 1, "Wave two must spawn one elite.")
	for enemy in (director.call("get_active_enemies") as Array).duplicate():
		enemy.call("take_hit", 9999, Vector2.ZERO, 0.0)
	await process_frame
	await process_frame
	_expect(cleared_rewards.size() == 1, "Clearing the final wave must emit one completion event.")
	if not cleared_rewards.is_empty():
		_expect(
			cleared_rewards[0].x > 0 and cleared_rewards[0].y > 0,
			"Encounter completion must aggregate positive EXP and gold."
		)

	director.queue_free()
	await process_frame


func _test_guardian_contract() -> void:
	var packed := load(GUARDIAN_SCENE) as PackedScene
	_expect(packed != null, "AutumnGuardian scene must load.")
	if packed == null:
		return

	var guardian := packed.instantiate()
	root.add_child(guardian)
	await process_frame
	var phase_events: Array[int] = []
	var telegraphs: Array[StringName] = []
	var drops: Array[Dictionary] = []
	guardian.connect("phase_changed", func(phase: int) -> void: phase_events.append(phase))
	guardian.connect(
		"attack_telegraphed",
		func(pattern: StringName, _duration: float) -> void: telegraphs.append(pattern)
	)
	guardian.connect(
		"drop_emitted",
		func(item_id: StringName, amount: int, _position: Vector2) -> void:
			drops.append({"id": item_id, "amount": amount})
	)

	_expect(int(guardian.get("phase")) == 1, "Guardian must begin in phase one.")
	_expect(
		(guardian.call("get_phase_patterns", 1) as Array).size() >= 1
		and (guardian.call("get_phase_patterns", 2) as Array).size() >= 1
		and (guardian.call("get_phase_patterns", 3) as Array).size() >= 1,
		"Guardian must define attacks for all three phases."
	)
	guardian.call("take_hit", 210, Vector2.ZERO, 0.0)
	_expect(int(guardian.get("phase")) == 2, "Guardian must enter phase two below two-thirds health.")
	guardian.call("take_hit", 210, Vector2.ZERO, 0.0)
	_expect(int(guardian.get("phase")) == 3, "Guardian must enter phase three below one-third health.")
	_expect(phase_events == [2, 3], "Guardian must emit each phase transition exactly once.")

	var chosen_pattern: StringName = guardian.call("perform_next_attack")
	_expect(not chosen_pattern.is_empty(), "Guardian must choose an attack in phase three.")
	_expect(telegraphs == [chosen_pattern], "Guardian must telegraph the chosen attack.")
	guardian.call("take_hit", 9999, Vector2.ZERO, 0.0)
	_expect(
		drops == [{"id": &"autumn_core", "amount": 1}],
		"Guardian defeat must emit exactly one autumn_core drop."
	)

	guardian.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
