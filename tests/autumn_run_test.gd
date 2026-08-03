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
	await _test_enemy_contact_damage_contract()
	await _test_enemy_player_contact_no_jump()
	await _test_enemy_platform_navigation()
	await _test_encounter_director()
	await _test_guardian_contract()
	quit(0 if _failures == 0 else 1)


func _test_archetype_catalog() -> void:
	var script := load(ARCHETYPE_SCRIPT) as GDScript
	_expect(script != null, "EnemyArchetype script must load.")
	if script == null:
		return

	var catalog: Dictionary = script.call("autumn_catalog")
	var expected_ids := [
		&"sprout", &"hopper", &"moth_swarm", &"thornling",
		&"charger", &"grove_shaman", &"elite",
	]
	_expect(catalog.size() == 7, "Autumn catalog must contain exactly seven archetypes.")
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
	for normal_id in expected_ids.slice(0, 6):
		var normal_enemy := catalog[normal_id] as EnemyArchetype
		var damage_after_defense := maxi(1, ember_damage - normal_enemy.defense)
		_expect(
			normal_enemy.max_health <= damage_after_defense,
			"%s must die to one default Ember Bolt hit." % normal_id
		)
	for normal_id in expected_ids.slice(0, 6):
		var normal_enemy := catalog[normal_id] as EnemyArchetype
		_expect(
			normal_enemy.experience_reward == 1,
			"%s must grant exactly one XP so dense crowds do not accelerate levels." % normal_id
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
	_expect(
		enemy.has_method("apply_survival_health_multiplier"),
		"EnemyBase must accept the survival director's health multiplier."
	)
	if enemy.has_method("apply_survival_health_multiplier"):
		var scaled_health := int(enemy.call("apply_survival_health_multiplier", 2.5))
		_expect(
			scaled_health == 25
				and int(enemy.get("health")) == 25
				and int(enemy.archetype.get("max_health")) == 25,
			"A Sprout at 2.5x survival health must have an authoritative 25 HP maximum."
		)
		enemy.call("reset_encounter", Vector2.ZERO)
		_expect(
			int(enemy.get("health")) == 25,
			"Encounter reset must preserve the current spawn's scaled maximum health."
		)
		enemy.call("configure_archetype", &"sprout")
	_expect(
		enemy.has_signal("hit_confirmed")
			and enemy.get_node_or_null("DamageNumber") != null
			and enemy.get_node_or_null("DeathBurst") != null,
		"Every enemy must expose per-target damage text and a visible defeat burst."
	)

	var hit_events: Array[Vector2i] = []
	if enemy.has_signal("hit_confirmed"):
		enemy.connect(
			"hit_confirmed",
			func(damage: int, lethal: bool) -> void:
				hit_events.append(Vector2i(damage, 1 if lethal else 0))
		)
	var health_before := int(enemy.get("health"))
	var applied := int(enemy.call("take_hit", 6, Vector2.ZERO, 0.0))
	_expect(applied == 6, "The early Sprout must take the full 6 raw test damage.")
	_expect(int(enemy.get("health")) == health_before - 6, "Enemy damage must reduce health.")
	var damage_number := enemy.get_node_or_null("DamageNumber") as Label
	_expect(
		hit_events == [Vector2i(6, 0)]
			and damage_number != null
			and damage_number.visible
			and damage_number.text == "-6",
		"Taking damage must immediately show a readable per-enemy hit confirmation."
	)
	var pursuit_target := Node2D.new()
	pursuit_target.position = enemy.position + Vector2(200.0, 0.0)
	root.add_child(pursuit_target)
	enemy.target = pursuit_target
	enemy.call("take_hit", 1, enemy.global_position + Vector2(80.0, 0.0), 120.0)
	enemy.call("_update_behavior")
	_expect(
		enemy.velocity.x < -1.0 and float(enemy.get("_hit_knockback_remaining")) > 0.0,
		"A surviving enemy must keep a brief visible knockback instead of resuming pursuit next frame."
	)
	pursuit_target.queue_free()

	_expect(enemy.call("configure_archetype", &"elite"), "Enemy must configure the elite archetype.")
	var first_pattern: StringName = enemy.call("perform_next_attack")
	var second_pattern: StringName = enemy.call("perform_next_attack")
	_expect(first_pattern == &"cleave", "Elite first attack must be cleave.")
	_expect(second_pattern == &"shockwave", "Elite second attack must be shockwave.")

	enemy.queue_free()
	var death_enemy := packed.instantiate()
	root.add_child(death_enemy)
	await process_frame
	var lethal_events: Array[Vector2i] = []
	death_enemy.connect(
		"hit_confirmed",
		func(damage: int, lethal: bool) -> void:
			lethal_events.append(Vector2i(damage, 1 if lethal else 0))
	)
	death_enemy.call("take_hit", 999, Vector2.ZERO, 0.0)
	var death_particles := death_enemy.get_node("DeathBurst") as CPUParticles2D
	_expect(
		lethal_events == [Vector2i(999, 1)] and death_particles.emitting,
		"A lethal hit must immediately trigger a per-enemy defeat burst."
	)
	death_enemy.queue_free()
	await process_frame


func _test_enemy_contact_damage_contract() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var enemy := packed.instantiate() as EnemyBase
	var player := player_scene.instantiate() as CharacterBody2D
	player.position = Vector2(50.0, 50.0)
	enemy.set_physics_process(false)
	player.set_physics_process(false)
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	_expect(enemy.configure_archetype(&"sprout"), "Contact damage test requires a Sprout.")
	enemy.set("_attacking", false)
	player.call("_clear_invulnerability")
	_expect(
		enemy.has_method("_try_apply_contact_damage"),
		"Every EnemyBase descendant must expose one shared physical contact-damage path."
	)
	var contact_area := enemy.get_node_or_null("ContactDamageArea") as Area2D
	_expect(
		contact_area != null
			and contact_area.collision_layer == 0
			and contact_area.collision_mask == 8,
		"Enemy contact damage must continuously monitor the player's Hurtbox layer."
	)
	if enemy.has_method("_try_apply_contact_damage"):
		var health_before := int(player.get("health"))
		var expected_raw_damage := maxi(
			1,
			roundi(
				float(enemy.archetype.get("attack_damage"))
					* float(enemy.get("contact_damage_multiplier"))
			)
		)
		var first_hit := int(enemy.call("_try_apply_contact_damage", player))
		_expect(
			first_hit > 0
				and first_hit <= expected_raw_damage
				and int(player.get("health")) == health_before - first_hit,
			"Physical enemy contact must pass archetype-scaled damage through Player.take_hit defenses."
		)
		player.call("_clear_invulnerability")
		var second_hit := int(enemy.call("_try_apply_contact_damage", player))
		_expect(
			second_hit == 0 and int(player.get("health")) == health_before - first_hit,
			"One enemy must not repeat contact damage before its own cooldown expires."
		)
		enemy.set("_contact_damage_remaining", 0.0)
		enemy.set("_attacking", true)
		enemy.set("_attack_generation", 7)
		player.call("_clear_invulnerability")
		var telegraph_overlap_hit := int(enemy.call("_try_apply_contact_damage", player))
		_expect(
			telegraph_overlap_hit > 0
				and int(enemy.get("_contact_hit_attack_generation")) == 7,
			"Physical overlap during a telegraph must still hurt and mark that attack generation resolved."
		)
		var health_after_contact := int(player.get("health"))
		player.call("_clear_invulnerability")
		enemy.target = player
		enemy.call("_apply_attack_pattern", &"jab", 1.0)
		_expect(
			int(player.get("health")) == health_after_contact,
			"A telegraphed attack must not double-hit after its overlap already dealt contact damage."
		)
		enemy.set("_contact_damage_remaining", 0.0)
		player.call("_clear_invulnerability")
		var health_before_area_tick := int(player.get("health"))
		enemy.set_physics_process(true)
		await physics_frame
		await physics_frame
		enemy.set_physics_process(false)
		_expect(
			int(player.get("health")) < health_before_area_tick,
			"The runtime ContactDamageArea must detect a stationary player overlap without relying on enemy slide motion."
		)

	enemy.queue_free()
	player.queue_free()
	await process_frame


func _test_enemy_player_contact_no_jump() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	var world := Node2D.new()
	root.add_child(world)

	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(600.0, 20.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	floor.position = Vector2(0.0, 100.0)
	world.add_child(floor)

	var player := player_scene.instantiate() as CharacterBody2D
	player.position = Vector2(180.0, 90.0)
	world.add_child(player)
	player.set_physics_process(false)

	var enemy := packed.instantiate() as EnemyBase
	enemy.position = Vector2(0.0, 90.0)
	world.add_child(enemy)
	await physics_frame
	await physics_frame
	_expect(enemy.configure_archetype(&"hopper"), "Player-contact navigation test requires a Hopper.")
	enemy.target = player
	var grounded_y := enemy.global_position.y
	var highest_y := grounded_y
	var jumped := false
	for _frame in 60:
		await physics_frame
		highest_y = minf(highest_y, enemy.global_position.y)
		jumped = jumped or enemy.velocity.y < -1.0
	_expect(
		not jumped and highest_y >= grounded_y - 2.0,
		"An enemy touching the player on flat ground must not treat the player body as a jumpable wall."
	)

	world.queue_free()
	await process_frame


func _test_enemy_platform_navigation() -> void:
	var packed := load(ENEMY_SCENE) as PackedScene
	var world := Node2D.new()
	root.add_child(world)

	var floor := StaticBody2D.new()
	floor.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(600.0, 20.0)
	floor_shape.shape = floor_rectangle
	floor.add_child(floor_shape)
	floor.position = Vector2(0.0, 100.0)
	world.add_child(floor)

	var platform := StaticBody2D.new()
	platform.collision_layer = 1
	var platform_shape := CollisionShape2D.new()
	var platform_rectangle := RectangleShape2D.new()
	platform_rectangle.size = Vector2(180.0, 12.0)
	platform_shape.shape = platform_rectangle
	platform_shape.one_way_collision = true
	platform.add_child(platform_shape)
	platform.position = Vector2(120.0, -4.0)
	world.add_child(platform)

	var target := Node2D.new()
	target.add_to_group("Player")
	target.position = Vector2(120.0, -34.0)
	world.add_child(target)

	var enemy := packed.instantiate() as EnemyBase
	enemy.position = Vector2(0.0, 90.0)
	world.add_child(enemy)
	await physics_frame
	await physics_frame
	enemy.target = target
	var grounded_y := enemy.global_position.y
	var highest_y := grounded_y
	for _frame in 36:
		await physics_frame
		highest_y = minf(highest_y, enemy.global_position.y)
	_expect(
		highest_y <= grounded_y - 60.0,
		"An enemy pursuing a player above it must physically jump toward the platform."
	)

	world.queue_free()
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
	var guardian_contact_area := guardian.get_node_or_null("ContactDamageArea") as Area2D
	_expect(
		guardian_contact_area != null and guardian_contact_area.collision_mask == 8,
		"Guardian must inherit the shared player Hurtbox contact-damage sensor."
	)
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
