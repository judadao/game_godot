class_name ExpeditionRegionCatalog
extends RefCounted

const BOSS_UNLOCK_CLEAR_COUNT := 4
const BATTLE_PORTAL_HUB_SCENE_PATH := "res://scenes/maps/battle_portal_hub.tscn"
const PORTAL_SLOT_ORDER: Array[StringName] = [&"autumn", &"crystal", &"hell", &"heaven"]
const VARIANT_ORDER: Array[StringName] = [
	&"autumn", &"crystal",
	&"hell_autumn", &"hell_crystal", &"hell",
	&"heaven_autumn", &"heaven_crystal", &"disorder_hell", &"heaven",
]
const VARIANT_DEFINITIONS := {
	&"autumn": {"display_name": "秋季戰場", "slot_id": &"autumn", "route_scene_path": "res://scenes/maps/autumn_forest.tscn", "boss_scene_path": "res://scenes/maps/boss/AutumnBossArena.tscn", "power_tier": 1},
	&"crystal": {"display_name": "水晶洞窟", "slot_id": &"crystal", "route_scene_path": "res://scenes/maps/crystal_caves.tscn", "boss_scene_path": "res://scenes/maps/boss/CrystalBossArena.tscn", "power_tier": 1},
	&"hell_autumn": {"display_name": "地獄秋季", "slot_id": &"autumn", "route_scene_path": "res://scenes/maps/expedition/HellAutumnRoute.tscn", "boss_scene_path": "res://scenes/maps/boss/HellAutumnBossArena.tscn", "power_tier": 2},
	&"hell_crystal": {"display_name": "地獄水晶", "slot_id": &"crystal", "route_scene_path": "res://scenes/maps/expedition/HellCrystalRoute.tscn", "boss_scene_path": "res://scenes/maps/boss/HellCrystalBossArena.tscn", "power_tier": 2},
	&"hell": {"display_name": "地獄裂隙", "slot_id": &"hell", "route_scene_path": "res://scenes/maps/hell_rift.tscn", "boss_scene_path": "res://scenes/maps/boss/HellBossArena.tscn", "power_tier": 3},
	&"heaven_autumn": {"display_name": "天堂秋季", "slot_id": &"autumn", "route_scene_path": "res://scenes/maps/expedition/HeavenAutumnRoute.tscn", "boss_scene_path": "res://scenes/maps/boss/HeavenAutumnBossArena.tscn", "power_tier": 3},
	&"heaven_crystal": {"display_name": "天堂水晶", "slot_id": &"crystal", "route_scene_path": "res://scenes/maps/expedition/HeavenCrystalRoute.tscn", "boss_scene_path": "res://scenes/maps/boss/HeavenCrystalBossArena.tscn", "power_tier": 3},
	&"disorder_hell": {"display_name": "無序地獄", "slot_id": &"hell", "route_scene_path": "res://scenes/maps/expedition/DisorderHellRoute.tscn", "boss_scene_path": "res://scenes/maps/boss/DisorderHellBossArena.tscn", "power_tier": 4},
	&"heaven": {"display_name": "天堂聖域", "slot_id": &"heaven", "route_scene_path": "res://scenes/maps/heaven_sanctuary.tscn", "boss_scene_path": "res://scenes/maps/boss/HeavenBossArena.tscn", "power_tier": 4},
}


func get_portal_slot_ids() -> Array[StringName]:
	return PORTAL_SLOT_ORDER.duplicate()


func get_variant_ids() -> Array[StringName]:
	return VARIANT_ORDER.duplicate()


func get_region_ids() -> Array[StringName]:
	return get_active_variant_ids("chapter_04")


func get_definition(variant_id: StringName) -> Dictionary:
	return (VARIANT_DEFINITIONS.get(variant_id, {}) as Dictionary).duplicate(true)


func get_display_name(variant_id: StringName) -> String:
	return String(get_definition(variant_id).get("display_name", variant_id))


func get_route_scene_path(variant_id: StringName) -> String:
	return String(get_definition(variant_id).get("route_scene_path", ""))


func get_boss_scene_path(variant_id: StringName) -> String:
	return String(get_definition(variant_id).get("boss_scene_path", ""))


func get_power_tier(variant_id: StringName) -> int:
	return maxi(1, int(get_definition(variant_id).get("power_tier", 1)))


func get_active_variant_ids(chapter_id: String) -> Array[StringName]:
	match _chapter_number(chapter_id):
		1, 2:
			return [&"autumn", &"crystal"]
		3:
			return [&"hell_autumn", &"hell_crystal", &"hell"]
		_:
			return [&"heaven_autumn", &"heaven_crystal", &"disorder_hell", &"heaven"]


func get_available_region_ids(chapter_id: String) -> Array[StringName]:
	return get_active_variant_ids(chapter_id)


func get_pending_boss_variant(
	chapter_id: String,
	clear_counts: Dictionary,
	boss_defeated: Dictionary
) -> StringName:
	for variant_id in get_active_variant_ids(chapter_id):
		if (
			int(clear_counts.get(String(variant_id), 0)) >= BOSS_UNLOCK_CLEAR_COUNT
			and not bool(boss_defeated.get(String(variant_id), false))
		):
			return variant_id
	return &""


func get_variant_for_slot(chapter_id: String, slot_id: StringName) -> StringName:
	for variant_id in get_active_variant_ids(chapter_id):
		if StringName(get_definition(variant_id).get("slot_id", &"")) == slot_id:
			return variant_id
	return &""


func get_region_id_for_scene(scene_path: String) -> StringName:
	for variant_id in VARIANT_ORDER:
		var definition := get_definition(variant_id)
		if scene_path in [String(definition.get("route_scene_path", "")), String(definition.get("boss_scene_path", ""))]:
			return variant_id
	return &""


func is_boss_scene(scene_path: String) -> bool:
	return not get_region_id_for_scene(scene_path).is_empty() and scene_path.ends_with("BossArena.tscn")


func _chapter_number(chapter_id: String) -> int:
	var digits := ""
	for character in chapter_id:
		if character >= "0" and character <= "9":
			digits += character
	return maxi(1, int(digits))
