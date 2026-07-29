extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame
	ui.call("set_items", [
		{"id": "wood", "name": "Autumn Wood", "category": "materials", "quantity": 12},
		{"id": "sword", "name": "Iron Sword", "category": "gear", "quantity": 1},
	])
	ui.call("set_codex_entries", [
		{"id": "ember_bolt", "name": "Ember Bolt", "category": "attacks", "preview_kind": "basic_attack"},
		{"id": "flame_imbue", "name": "Flame Imbue", "category": "infusions", "preview_kind": "attack_aura", "elements": ["flame"]},
		{"id": "frost_bind", "name": "Glacial Dominion", "category": "skills", "preview_kind": "ice_ultimate", "radius": 460},
		{"id": "guard", "name": "Iron Will", "category": "skills", "preview_kind": "technique", "visual_family": "defense"},
		{"id": "healing_light", "name": "Healing Light", "category": "skills", "preview_kind": "technique", "visual_family": "healing"},
		{
			"id": "inferno_cremation", "name": "Inferno Cremation",
			"category": "finishers", "preview_kind": "finisher",
			"named_vfx_id": "inferno_cremation", "elements": ["fire"],
			"level": 3, "combo_stack": 7,
		},
	])
	ui.call("set_mode", &"codex")
	ui.call("open")
	await process_frame
	await process_frame
	ui.call("select_codex_entry", "flame_imbue")
	await process_frame
	_expect(ui.call("get_mode") == &"codex", "Codex mode must be selectable.")
	_expect(ui.call("get_visible_codex_count") == 6, "Codex must list every projected attack, skill, infusion, and finisher.")
	_expect(ui.call("get_selected_codex_id") == "flame_imbue", "Codex selection must drive the preview.")
	var preview := ui.get_node("Center/MainPanel/Margin/Layout/Pages/CodexPage/Details/Preview")
	_expect(preview.call("get_preview_kind") == "attack_aura", "Attack infusion must use the aura preview.")
	_expect(preview.call("get_effect_node_count") == 1, "Preview must own exactly one active reusable effect.")
	_expect(
		not bool(preview.call("is_effect_top_level")),
		"Codex preview combat effects must stay clipped inside the preview panel."
	)
	ui.call("select_codex_entry", "ember_bolt")
	_expect(preview.call("get_preview_kind") == "basic_attack", "Basic attacks must use the directional strike preview.")
	_expect(
		float(preview.call("get_sword_wave_speed_multiplier")) >= 1.0,
		"Codex Basic Attack previews must retain the slash-shockwave speed."
	)
	_expect(
		(preview.call("get_effect_origin_offset_from_preview_center") as Vector2).is_equal_approx(
			Vector2(34.0, 7.0)
		),
		"Codex sword waves must launch beside the character in preview-local coordinates at every viewport stretch."
	)
	_expect(
		not bool(preview.call("is_effect_top_level")),
		"Basic Attack preview must not escape the codex panel as a top-level world effect."
	)
	ui.call("select_codex_entry", "guard")
	_expect(preview.call("get_preview_kind") == "technique", "Defense and support skills must use the reusable technique preview.")
	ui.call("select_codex_entry", "inferno_cremation")
	_expect(preview.call("get_preview_kind") == "finisher", "Finishers must use the amplified sword-wave preview.")
	_expect(
		preview.call("get_active_named_vfx_id") == "inferno_cremation",
		"Finisher previews must preserve the exact named VFX identity."
	)
	_expect(
		int(preview.call("get_active_effect_evolution_level")) == 3
			and int(preview.call("get_active_effect_buff_stacks")) == 7,
		"Codex named VFX previews must preserve entry evolution level and persistent buff stacks."
	)
	ui.queue_free()
	viewport.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: Inventory and discovery codex behavior")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
