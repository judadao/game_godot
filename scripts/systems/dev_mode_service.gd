class_name DevModeService
extends RefCounted

const SETTING_PATH := "development/dev_mode_enabled"
const RESOURCE_AMOUNT := 999999


func is_enabled() -> bool:
	if _is_automated_test_run() and not bool(
		ProjectSettings.get_setting("development/force_dev_mode_in_tests", false)
	):
		return false
	return bool(ProjectSettings.get_setting(SETTING_PATH, true))


func _is_automated_test_run() -> bool:
	for argument in OS.get_cmdline_args():
		var value := String(argument)
		if value.begins_with("res://tests/") or "/tests/" in value:
			return true
	return false


func apply_runtime_unlocks(
	meta_state: MetaState,
	inventory_manager: RefCounted,
	card_database: RefCounted,
	skill_manager: RefCounted,
	forge_catalog: RefCounted,
	town_manager: RefCounted
) -> Dictionary:
	if not is_enabled():
		return {}
	for resource_id in inventory_manager.call("get_resource_ids") as Array[StringName]:
		inventory_manager.call("set_resource_amount", resource_id, RESOURCE_AMOUNT)
	for item_variant in inventory_manager.call("get_equipment_catalog") as Array:
		var item_id := StringName((item_variant as Dictionary).get("id", ""))
		if not item_id.is_empty() and not bool(inventory_manager.call("has_equipment", item_id)):
			inventory_manager.call("add_equipment", item_id)
	for offer_variant in forge_catalog.call("get_all_offers") as Array:
		var offer := offer_variant as Dictionary
		var product_id := StringName(offer.get("product_id", ""))
		match StringName(offer.get("product_kind", "")):
			&"blueprint":
				inventory_manager.call("grant_blueprint", product_id)
			&"tool":
				inventory_manager.call("grant_tool", product_id)

	var card_ids: Array[String] = []
	for card_variant in card_database.call("get_all_cards") as Array:
		var card_id := String((card_variant as Dictionary).get("id", ""))
		if not card_id.is_empty():
			card_ids.append(card_id)
	meta_state.unlocked_cards.assign(card_ids)

	var skill_ids: Array[String] = []
	for skill_variant in skill_manager.call("get_all_skills") as Array:
		var skill_id := String((skill_variant as Dictionary).get("id", ""))
		if not skill_id.is_empty():
			skill_ids.append(skill_id)
	meta_state.learned_skill_ids.assign(skill_ids)
	meta_state.active_skill_ids.assign(skill_ids)
	meta_state.dash_upgrade_unlocked = true
	meta_state.shortcuts["expedition_power_tier"] = 4
	meta_state.shortcuts["dev_mode_enabled"] = true

	var building_levels: Dictionary = {}
	for building_id in town_manager.call("get_building_ids") as Array[StringName]:
		building_levels[String(building_id)] = int(
			town_manager.call("get_max_building_level", building_id)
		)
	town_manager.call("apply_dict", {"building_levels": building_levels})
	return {
		"resource_amount": RESOURCE_AMOUNT,
		"equipment_count": (inventory_manager.call("get_equipment_catalog") as Array).size(),
		"sword_soul_count": card_ids.size(),
		"skill_count": skill_ids.size(),
	}


func get_map_entries(expedition_catalog: RefCounted) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen_paths: Dictionary = {}
	_append_map(entries, seen_paths, "城鎮｜永恆熔爐", "res://scenes/maps/town.tscn")
	_append_map(entries, seen_paths, "戰區｜傳送聖所", "res://scenes/maps/battle_portal_hub.tscn")
	_append_map(entries, seen_paths, "休整｜秋季安全區", "res://scenes/maps/autumn_safe_zone.tscn")
	for variant_id in expedition_catalog.call("get_variant_ids") as Array[StringName]:
		var display_name := String(expedition_catalog.call("get_display_name", variant_id))
		_append_map(
			entries,
			seen_paths,
			"戰區｜%s" % display_name,
			String(expedition_catalog.call("get_route_scene_path", variant_id)),
			variant_id,
			false
		)
	_append_map(entries, seen_paths, "相容｜禁忌墓園", "res://scenes/maps/forbidden_graveyard.tscn")
	for variant_id in expedition_catalog.call("get_variant_ids") as Array[StringName]:
		var display_name := String(expedition_catalog.call("get_display_name", variant_id))
		_append_map(
			entries,
			seen_paths,
			"Boss｜%s" % display_name,
			String(expedition_catalog.call("get_boss_scene_path", variant_id)),
			variant_id,
			true
		)
	return entries


func _append_map(
	entries: Array[Dictionary],
	seen_paths: Dictionary,
	label: String,
	scene_path: String,
	variant_id: StringName = &"",
	is_boss: bool = false
) -> void:
	if scene_path.is_empty() or seen_paths.has(scene_path):
		return
	seen_paths[scene_path] = true
	entries.append({
		"label": label,
		"scene_path": scene_path,
		"variant_id": String(variant_id),
		"is_boss": is_boss,
	})
