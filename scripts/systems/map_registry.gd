class_name MapRegistry
extends RefCounted

const TOWN_SCENE_PATH := "res://scenes/maps/town.tscn"
const AUTUMN_FOREST_SCENE_PATH := "res://scenes/maps/autumn_forest.tscn"
const CRYSTAL_CAVES_SCENE_PATH := "res://scenes/maps/crystal_caves.tscn"
const FORBIDDEN_GRAVEYARD_SCENE_PATH := "res://scenes/maps/forbidden_graveyard.tscn"
const TOWN_MAIN_SCENE_PATH := "res://scenes/maps/town/TownMap.tscn"
const AUTUMN_BATTLE_MAIN_SCENE_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"
const AUTUMN_TREE_MAIN_SCENE_PATH := AUTUMN_BATTLE_MAIN_SCENE_PATH
const CRYSTAL_CAVES_LAYOUT_SCENE_PATH := "res://scenes/maps/layouts/CrystalCavesLayout.tscn"
const FORBIDDEN_GRAVEYARD_LAYOUT_SCENE_PATH := "res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn"
const CANONICAL_TO_AUTHORITATIVE := {
	TOWN_SCENE_PATH: TOWN_MAIN_SCENE_PATH,
	AUTUMN_FOREST_SCENE_PATH: AUTUMN_TREE_MAIN_SCENE_PATH,
	CRYSTAL_CAVES_SCENE_PATH: CRYSTAL_CAVES_LAYOUT_SCENE_PATH,
	FORBIDDEN_GRAVEYARD_SCENE_PATH: FORBIDDEN_GRAVEYARD_LAYOUT_SCENE_PATH,
}


func resolve(scene_path: String) -> String:
	return String(CANONICAL_TO_AUTHORITATIVE.get(canonical(scene_path), scene_path))


func canonical(scene_path: String) -> String:
	for canonical_path in CANONICAL_TO_AUTHORITATIVE:
		if scene_path == String(CANONICAL_TO_AUTHORITATIVE[canonical_path]):
			return String(canonical_path)
	return scene_path


func matches(scene_path: String, canonical_path: String) -> bool:
	return canonical(scene_path) == canonical_path
