extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var meta := game.get("meta_state") as MetaState
	# Learned-but-unequipped content must not leak back into the live move review.
	meta.auto_attack_card_id = "ember_bolt"
	meta.set_selected_deck([
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])
	for instance in meta.selected_card_instances:
		if instance.card_id == "echo_volley":
			instance.level = 3
	meta.learned_skill_ids = ["iron_momentum", "ember_reprise"]
	meta.active_skill_ids = ["iron_momentum"]
	var projection := game.call("_inventory_codex_projection") as Array
	var entries_by_id: Dictionary = {}
	for entry_variant in projection:
		var entry := entry_variant as Dictionary
		var entry_id := String(entry.get("id", ""))
		_expect(not entry_id.is_empty(), "Every codex entry must expose a stable id.")
		_expect(not entries_by_id.has(entry_id), "Codex projection must not duplicate id: %s." % entry_id)
		entries_by_id[entry_id] = entry
		_expect(
			not String(entry.get("effect_summary", "")).is_empty()
				and not String(entry.get("trigger_summary", "")).is_empty(),
			"Every discovered technique needs effect and activation details: %s." % entry_id
		)
		_expect(
			String(entry.get("preview_kind", "")) in [
				"basic_attack",
				"attack_aura",
				"technique",
				"passive_skill",
				"fire_ultimate",
				"ice_ultimate",
				"finisher",
				"storm_charge",
			],
			"Every discovered technique needs a supported preview: %s." % entry_id
		)

	var expected_live_cards := [
		meta.auto_attack_card_id,
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	]
	for card_id in expected_live_cards:
		_expect(
			entries_by_id.has(card_id),
			"Every currently equipped move must appear exactly once in the live codex: %s."
				% card_id
		)
	_expect(
		not entries_by_id.has("guard") and not entries_by_id.has("ember_reprise"),
		"Unequipped legacy cards and inactive learned skills must not leak into the live move review."
	)
	for skill_id in meta.active_skill_ids:
		_expect(
			entries_by_id.has(skill_id),
			"Every active passive skill must appear in the live codex: %s." % skill_id
		)
		if entries_by_id.has(skill_id):
			_expect(
				String((entries_by_id[skill_id] as Dictionary).get("named_vfx_id", "")) == skill_id,
				"Learned named skills must keep their exact preview identity: %s." % skill_id
			)
			var skill_entry := entries_by_id[skill_id] as Dictionary
			_expect(
				not String(skill_entry.get("element", "")).is_empty()
					and (skill_entry.get("evolution_layers", []) as Array).size() == 3
					and (skill_entry.get("stack_milestones", []) as Array).size() >= 3
					and (
						(skill_entry.get("stack_milestones", []) as Array).size()
						== (skill_entry.get("stack_traits", []) as Array).size()
					),
				"Learned named skills must project element, evolution, and Buff milestone data: %s."
					% skill_id
			)

	_expect(
		String((entries_by_id.get("ember_bolt", {}) as Dictionary).get("category", "")) == "attacks",
		"Equipped attack techniques must remain in Basic Attacks."
	)
	_expect(
		((entries_by_id.get("ember_bolt", {}) as Dictionary).get("elements", []) as Array).is_empty(),
		"Basic Attack codex previews must stay neutral until a Combo infusion adds an element."
	)
	_expect(
		String((entries_by_id.get("flame_imbue", {}) as Dictionary).get("category", "")) == "infusions",
		"Equipped attack infusions must no longer disappear from the codex."
	)
	_expect(
		String((entries_by_id.get("storm_charge", {}) as Dictionary).get("preview_kind", ""))
			== "storm_charge",
		"Storm Charge must preview its dedicated in-place animation instead of a generic attack aura."
	)
	_expect(
		String((entries_by_id.get("storm_charge", {}) as Dictionary).get("special_vfx_id", ""))
			== "storm_charge",
		"Live Codex metadata must use the same Storm Charge special VFX identity as combat."
	)
	var echo_entry := entries_by_id.get("echo_volley", {}) as Dictionary
	_expect(
		int(echo_entry.get("level", 0)) == 3
			and int(echo_entry.get("direction_count", 0)) == 8
			and is_equal_approx(float(echo_entry.get("spread_degrees", 0.0)), 360.0),
		"Live Codex metadata must apply the equipped instance level and exact volley geometry."
	)
	var echo_preview := InventoryCodexPreview.new()
	echo_preview.size = Vector2(640.0, 320.0)
	root.add_child(echo_preview)
	echo_preview.show_entry(echo_entry)
	await process_frame
	_expect(
		int(echo_preview.get_sword_wave_count()) == 8,
		"Echo Volley must preview all eight level-three projectiles instead of one generic wave."
	)
	var echo_angles: Array[int] = []
	for offset in echo_preview.get_sword_wave_travel_offsets():
		echo_angles.append(roundi(rad_to_deg(offset.angle())))
	echo_angles.sort()
	_expect(
		echo_angles == [-135, -90, -45, 0, 45, 90, 135, 180],
		"Echo Volley preview must preserve the production 360-degree direction fan: %s."
			% [echo_angles]
	)
	echo_preview.queue_free()
	for skill_card_id in ["healing_light"]:
		_expect(
			String((entries_by_id.get(skill_card_id, {}) as Dictionary).get("category", "")) == "skills",
			"Current healing techniques must appear under Skills: %s."
				% skill_card_id
		)
	var finisher_count := 0
	for recipe_variant in (game.get("combo_finisher_catalog") as RefCounted).call("get_all_recipes") as Array:
		var recipe := recipe_variant as Dictionary
		var finisher_id := String(recipe.get("id", ""))
		_expect(
			entries_by_id.has(finisher_id),
			"Every current production Finisher must remain reviewable in the live Codex: %s."
				% finisher_id
		)
		if entries_by_id.has(finisher_id):
			finisher_count += 1
			_expect(
				String((entries_by_id[finisher_id] as Dictionary).get("named_vfx_id", ""))
					== finisher_id,
				"Every Finisher entry must instantiate the same exact named VFX id as combat: %s."
					% finisher_id
			)
	_expect(finisher_count == 32, "The live Codex must expose all 32 current production Finishers.")

	var capture_path := OS.get_environment("INVENTORY_CODEX_PROJECTION_CAPTURE_PATH")
	if not capture_path.is_empty():
		game.call("_open_inventory")
		await process_frame
		var inventory_ui := game.call("get_open_ui", "InventoryUI") as Control
		_expect(inventory_ui != null, "Runtime projection capture requires the real Inventory UI.")
		if inventory_ui != null:
			inventory_ui.call("set_mode", &"codex")
			var capture_section := OS.get_environment("INVENTORY_CODEX_PROJECTION_SECTION")
			if not capture_section.is_empty():
				var filter := inventory_ui.get_node(
					"Center/MainPanel/Margin/Layout/Pages/CodexPage/Browser/Filter"
				) as OptionButton
				for filter_index in filter.item_count:
					if String(filter.get_item_metadata(filter_index)) != capture_section:
						continue
					filter.select(filter_index)
					filter.item_selected.emit(filter_index)
					break
			inventory_ui.call("select_codex_entry", "storm_charge")
			await create_timer(0.18).timeout
			await RenderingServer.frame_post_draw
			_expect(
				root.get_texture().get_image().save_png(capture_path) == OK,
				"Runtime discovery codex capture must save."
			)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: complete discovered technique codex projection")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
