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
		{"id": "inferno_cremation", "name": "Inferno Cremation", "category": "finishers", "preview_kind": "finisher", "elements": ["flame"]},
	])
	ui.call("set_mode", &"codex")
	ui.call("select_codex_entry", "flame_imbue")
	await process_frame
	_expect(ui.call("get_mode") == &"codex", "Codex mode must be selectable.")
	_expect(ui.call("get_visible_codex_count") == 4, "Codex must list attacks, skills, infusions, and finishers.")
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
		not bool(preview.call("is_effect_top_level")),
		"Basic Attack preview must not escape the codex panel as a top-level world effect."
	)
	ui.call("select_codex_entry", "inferno_cremation")
	_expect(preview.call("get_preview_kind") == "finisher", "Finishers must use the amplified sword-wave preview.")
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
