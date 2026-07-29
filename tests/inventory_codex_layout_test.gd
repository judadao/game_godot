extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(2560, 1440),
]

var _failures := 0
var _capture_path := ""
var _capture_size := Vector2i.ZERO
var _capture_entry_id := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_path = OS.get_environment("INVENTORY_CODEX_CAPTURE_PATH")
	_capture_size = _parse_size(OS.get_environment("INVENTORY_CODEX_CAPTURE_SIZE"))
	_capture_entry_id = OS.get_environment("INVENTORY_CODEX_CAPTURE_ENTRY")
	for viewport_size in VIEWPORT_SIZES:
		await _check_size(viewport_size)
	if _failures == 0:
		print("PASS: Inventory codex layout at six viewport sizes")
	quit(1 if _failures > 0 else 0)


func _check_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame
	ui.call("set_codex_entries", [
		{
			"id": "ember_bolt", "name": "Ember Bolt", "category": "attacks",
			"kind_label": "BASIC ATTACK",
			"description": "Deal 16 damage and apply burn.",
			"effect_summary": "16 damage, 2 burn damage, 260 attack range",
			"trigger_summary": "Fires automatically toward enemies in front of the player.",
			"preview_kind": "basic_attack", "elements": [],
			"icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png",
		},
		{
			"id": "flame_imbue", "name": "Flame Imbue", "category": "infusions",
			"kind_label": "FLAME ATTACK INFUSION",
			"description": "Wrap every weapon strike in fire and inflict Burn.",
			"effect_summary": "+4 attack damage, 3 burn damage",
			"trigger_summary": "Wraps your attacks for 2.5 seconds.",
			"preview_kind": "attack_aura", "elements": ["flame"], "intensity": 3,
			"icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/BlueSet_0003_Chest.png",
		},
		{
			"id": "frost_bind", "name": "Glacial Dominion", "category": "skills",
			"preview_kind": "ice_ultimate",
		},
		{
			"id": "inferno_cremation", "name": "Inferno Cremation",
			"category": "finishers", "kind_label": "COMBO FINISHER",
			"description": "Compress three flame invocations into one execution.",
			"effect_summary": "+44 attack damage, 2.00x effect size",
			"trigger_summary": "Formula: Flame Imbue > Flame Imbue > Flame Imbue",
			"preview_kind": "finisher", "elements": ["flame"], "intensity": 5,
			"attack_size_multiplier": 2.0, "stack_count": 3,
		},
	])
	ui.call("set_mode", &"codex")
	ui.call("open")
	var selected_entry_id := (
		_capture_entry_id
		if viewport_size == _capture_size and not _capture_entry_id.is_empty()
		else "ember_bolt"
	)
	ui.call("select_codex_entry", selected_entry_id)
	await process_frame
	await process_frame
	var panel := ui.get_node("Center/MainPanel") as Control
	var browser := panel.get_node("Margin/Layout/Pages/CodexPage/Browser") as Control
	var preview := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Preview") as Control
	var info := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Info") as Control
	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	_expect(screen.encloses(_rect(panel)), "Panel must remain on-screen at %s." % viewport_size)
	_expect(not _rect(browser).intersects(_rect(preview)), "Discovery list must not overlap preview at %s." % viewport_size)
	_expect(_rect(preview).end.y <= _rect(info).position.y, "Preview must remain above explanation at %s." % viewport_size)
	var effect_origin_offset := (
		preview.call("get_effect_origin_offset_from_preview_center") as Vector2
	)
	var effect_travel_offset := preview.call("get_effect_travel_offset") as Vector2
	_expect(
		effect_origin_offset.is_equal_approx(Vector2(34.0, 7.0)),
		"Basic Attack VFX origin must remain beside the preview character at %s; got %s."
			% [viewport_size, effect_origin_offset]
	)
	_expect(
		effect_travel_offset.x > 0.0 and absf(effect_travel_offset.y) <= 0.01,
		"Basic Attack VFX must travel horizontally to the character's right at %s; got %s."
			% [viewport_size, effect_travel_offset]
	)
	if viewport_size == _capture_size and not _capture_path.is_empty():
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await create_timer(0.12).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(viewport.get_texture().get_image().save_png(_capture_path) == OK, "Visual capture must save.")
	ui.queue_free()
	viewport.queue_free()
	await process_frame


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _parse_size(raw_size: String) -> Vector2i:
	var parts := raw_size.to_lower().split("x")
	return Vector2i(int(parts[0]), int(parts[1])) if parts.size() == 2 else Vector2i.ZERO


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
