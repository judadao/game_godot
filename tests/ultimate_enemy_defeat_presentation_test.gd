extends SceneTree

const ENEMY_SCENE := preload("res://scenes/monsters/AutumnEnemy.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(
		database.load_catalog(),
		"Ultimate defeat presentation requires the production card catalog."
	)
	var runner := CardEffectRunner.new()
	root.add_child(runner)
	var inferno_card := database.get_card("inferno_orb")
	var inferno_profile := runner.call(
		"_resolve_hit_presentation",
		inferno_card,
		inferno_card.get("effect", {}) as Dictionary
	) as Dictionary
	_expect(
		String(inferno_profile.get("kind", "")) == "ultimate"
			and String(inferno_profile.get("element", "")) == "fire"
			and float(inferno_profile.get("impact_delay_seconds", 0.0)) >= 0.50,
		"Inferno Orb's wide ultimate presentation must use the same delayed fire defeat timing."
	)
	var caster := Node2D.new()
	root.add_child(caster)
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	root.add_child(enemy)
	await process_frame
	caster.position = Vector2(480.0, 360.0)
	enemy.position = caster.position
	enemy.configure_archetype(&"sprout")
	var defeat_events: Array[Dictionary] = []
	enemy.defeated.connect(
		func(defeated_enemy: Node, experience: int, gold: int) -> void:
			defeat_events.append({
				"enemy": defeated_enemy,
				"experience": experience,
				"gold": gold,
			})
	)
	_expect(
		enemy.has_method("prepare_hit_presentation")
			and enemy.has_method("get_defeat_presentation_state"),
		"EnemyBase must expose one common damage-presentation handoff and diagnostics."
	)

	Engine.time_scale = 0.12
	var result := runner.cast(
		database.get_card("concussive_shout"),
		caster,
		[enemy]
	)
	var state: Dictionary = (
		enemy.call("get_defeat_presentation_state") as Dictionary
		if is_instance_valid(enemy)
			and enemy.has_method("get_defeat_presentation_state")
		else {}
	)
	_expect(
		int(result.get("affected", 0)) == 1
			and int(enemy.get("health")) == 0
			and defeat_events.size() == 1
			and enemy.collision_layer == 0
			and enemy.collision_mask == 0,
		"Ultimate lethality must settle health, rewards, and collision immediately."
	)
	_expect(
		bool(state.get("active", false))
			and String(state.get("timeline", "")) == "hit_dissolve_burst"
			and bool(state.get("ignores_time_scale", false))
			and float(state.get("impact_delay_seconds", 0.0)) >= 0.50
			and float(state.get("impact_delay_seconds", 0.0)) <= 0.65
			and float(state.get("cleanup_seconds", 0.0)) >= 0.95
			and float(state.get("cleanup_seconds", 0.0)) <= 1.25
			and int(state.get("presentation_node_count", 0)) >= 4
			and int(state.get("presentation_node_count", 0)) <= 12,
		"Fire lethality must expose an unscaled timeline aligned to its visual impact."
	)
	var impact_core := enemy.get_node_or_null(
		"UltimateDeathPresentation/ImpactCore"
	) as CanvasItem
	var enemy_visual := enemy.get_node_or_null("Visual") as CanvasItem
	_expect(
		impact_core != null
			and impact_core.modulate.a <= 0.01
			and enemy_visual != null
			and enemy_visual.modulate.a >= 0.9,
		"Impact geometry must stay hidden during hold so the defeated enemy silhouette remains readable."
	)

	await create_timer(0.46, true, false, true).timeout
	if is_instance_valid(enemy):
		state = enemy.call("get_defeat_presentation_state") as Dictionary
	_expect(
		is_instance_valid(enemy)
			and String(state.get("phase", "")) == "impact_hold"
			and bool(state.get("gameplay_settled", false)),
		"Fire defeat must remain visibly held before the ultimate reaches its impact frame."
	)

	await create_timer(0.18, true, false, true).timeout
	if is_instance_valid(enemy):
		state = enemy.call("get_defeat_presentation_state") as Dictionary
	var capture_path := OS.get_environment(
		"ULTIMATE_ENEMY_DEFEAT_CAPTURE_PATH"
	)
	if not capture_path.is_empty():
		var capture_delay := maxf(
			0.0,
			float(OS.get_environment(
				"ULTIMATE_ENEMY_DEFEAT_CAPTURE_DELAY"
			))
		)
		if capture_delay > 0.0:
			await create_timer(capture_delay, true, false, true).timeout
		await RenderingServer.frame_post_draw
		_expect(
			root.get_texture().get_image().save_png(capture_path) == OK,
			"Ultimate enemy defeat visual capture must save."
		)
	_expect(
		is_instance_valid(enemy)
			and String(state.get("phase", "")) in ["dissolve", "burst"]
			and enemy_visual.modulate.a >= 0.35,
		"Fire defeat must dissolve or burst only after the ultimate impact frame."
	)

	await create_timer(0.62, true, false, true).timeout
	await process_frame
	_expect(
		not is_instance_valid(enemy),
		"Ultimate defeat presentation must clean itself on real time even during slow motion."
	)

	var ice_enemy := ENEMY_SCENE.instantiate() as EnemyBase
	root.add_child(ice_enemy)
	await process_frame
	ice_enemy.position = caster.position
	ice_enemy.configure_archetype(&"sprout")
	var ice_defeat_events: Array[bool] = []
	ice_enemy.defeated.connect(
		func(_enemy: Node, _experience: int, _gold: int) -> void:
			ice_defeat_events.append(true)
	)
	runner.cast(database.get_card("frost_bind"), caster, [ice_enemy])
	var ice_state := (
		ice_enemy.call("get_defeat_presentation_state") as Dictionary
	)
	_expect(
		ice_defeat_events.size() == 1
			and String(ice_state.get("element", "")) == "ice"
			and bool(ice_state.get("active", false))
			and float(ice_state.get("impact_delay_seconds", 0.0)) >= 0.85
			and float(ice_state.get("impact_delay_seconds", 0.0)) <= 1.10,
		"Fire and ice ultimates must both reach the common defeat presentation with their element identity."
	)
	await create_timer(0.84, true, false, true).timeout
	if is_instance_valid(ice_enemy):
		ice_state = (
			ice_enemy.call("get_defeat_presentation_state") as Dictionary
		)
	_expect(
		is_instance_valid(ice_enemy)
			and String(ice_state.get("phase", "")) == "impact_hold",
		"Ice defeat must retain the enemy until the delayed shatter impact."
	)
	await create_timer(0.78, true, false, true).timeout
	await process_frame
	_expect(
		not is_instance_valid(ice_enemy),
		"Ice defeat presentation must clean itself after its delayed impact finishes."
	)
	Engine.time_scale = 1.0
	if is_instance_valid(enemy):
		enemy.queue_free()
	caster.queue_free()
	runner.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: ultimate lethality settles immediately and presents an unscaled enemy defeat")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
