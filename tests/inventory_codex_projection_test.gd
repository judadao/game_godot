extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

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
			],
			"Every discovered technique needs a supported preview: %s." % entry_id
		)

	var meta := game.get("meta_state") as MetaState
	for card_id in meta.unlocked_cards:
		_expect(
			entries_by_id.has(card_id),
			"Every unlocked card must appear exactly once in the discovery codex: %s." % card_id
		)
	for skill_id in meta.learned_skill_ids:
		_expect(
			entries_by_id.has(skill_id),
			"Every learned passive skill must appear in the discovery codex: %s." % skill_id
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
		String((entries_by_id.get("battle_rhythm", {}) as Dictionary).get("category", "")) == "infusions",
		"Non-elemental attack infusions must no longer disappear from the codex."
	)
	for skill_card_id in ["guard", "healing_light", "energy_surge", "blood_pact_combo"]:
		_expect(
			String((entries_by_id.get(skill_card_id, {}) as Dictionary).get("category", "")) == "skills",
			"Defense, healing, energy, and status techniques must appear under Skills: %s."
				% skill_card_id
		)

	var capture_path := OS.get_environment("INVENTORY_CODEX_PROJECTION_CAPTURE_PATH")
	if not capture_path.is_empty():
		game.call("_open_inventory")
		await process_frame
		var inventory_ui := game.call("get_open_ui", "InventoryUI") as Control
		_expect(inventory_ui != null, "Runtime projection capture requires the real Inventory UI.")
		if inventory_ui != null:
			inventory_ui.call("set_mode", &"codex")
			inventory_ui.call("select_codex_entry", "guard")
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
