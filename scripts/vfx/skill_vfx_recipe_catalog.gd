class_name SkillVFXRecipeCatalog
extends RefCounted

const SERIES_CATALOG_SCRIPT := preload("res://scripts/systems/skill_series_vfx_catalog.gd")
const GRAMMAR_IDS := [
	"core", "trail", "arc", "beam", "bolt", "ring", "burst", "impact",
	"projectile", "orbit", "rain", "aura", "ground_zone", "afterimage",
	"distortion",
]
const RECIPE_ORDER := [
	"sword_rain", "moon_wheel", "feather", "ancient_wood", "giant_stone",
	"great_shield", "fire", "lightning", "water_flow", "plant_attack",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const RECIPE_GRAMMAR := {
	"sword_rain": ["core", "rain", "projectile", "trail", "impact", "ring"],
	"moon_wheel": ["core", "orbit", "projectile", "trail", "ring", "impact"],
	"feather": ["core", "projectile", "trail", "afterimage", "ring", "impact"],
	"ancient_wood": ["core", "aura", "beam", "ground_zone", "ring", "impact"],
	"giant_stone": ["core", "projectile", "orbit", "trail", "burst", "impact", "ground_zone"],
	"great_shield": ["core", "aura", "ring", "beam", "impact", "ground_zone"],
	"fire": ["core", "projectile", "trail", "distortion", "burst", "impact", "ground_zone"],
	"lightning": ["core", "bolt", "beam", "trail", "ring", "impact", "burst"],
	"water_flow": ["core", "arc", "trail", "projectile", "ring", "impact", "ground_zone"],
	"plant_attack": ["core", "ground_zone", "rain", "projectile", "aura", "impact"],
	"dragon_breath": ["core", "beam", "trail", "distortion", "ring", "impact", "burst"],
	"dawn_vitality": ["core", "aura", "ring", "rain", "impact", "ground_zone"],
	"shared_branch_vitality": ["core", "beam", "aura", "afterimage", "ring", "impact", "ground_zone"],
}
const BASE_PALETTES := {
	"sword_rain": ["ecfbff", "79cfff", "6f72ff"],
	"moon_wheel": ["fffbe2", "a8c9ff", "7162d8"],
	"feather": ["fffce8", "f6d982", "9a72e8"],
	"ancient_wood": ["efffc9", "7fca70", "315f43"],
	"giant_stone": ["fff0c5", "c3935f", "5e4b43"],
	"great_shield": ["fff4c7", "d9aa52", "7755aa"],
	"fire": ["fff0a0", "ff641d", "8c1811"],
	"lightning": ["f7ffff", "6fdcff", "765cff"],
	"water_flow": ["e9ffff", "49c8e8", "2267b2"],
	"plant_attack": ["efffb0", "70cf55", "56306d"],
	"dragon_breath": ["fff1ff", "b36cff", "47237f"],
	"dawn_vitality": ["fff7b8", "ffbe55", "d8673d"],
	"shared_branch_vitality": ["f3ffd0", "8cd071", "3d765c"],
}
const DEFAULT_IMPACTS := {
	"sword_rain": "lightning_impact",
	"moon_wheel": "wind_burst",
	"feather": "wind_burst",
	"ancient_wood": "wind_burst",
	"giant_stone": "wind_burst",
	"great_shield": "lightning_impact",
	"fire": "fire_burst",
	"lightning": "lightning_impact",
	"water_flow": "water_splash",
	"plant_attack": "poison_splash",
	"dragon_breath": "fire_burst",
	"dawn_vitality": "wind_burst",
	"shared_branch_vitality": "wind_burst",
}

var _series_catalog: RefCounted = SERIES_CATALOG_SCRIPT.new()
var _recipes: Dictionary = {}


func load_catalog() -> bool:
	_recipes.clear()
	if not bool(_series_catalog.call("load_catalog")):
		return false
	for series_id in RECIPE_ORDER:
		var series_profile := _series_catalog.call("get_profile", series_id) as Dictionary
		var grammar := (RECIPE_GRAMMAR.get(series_id, []) as Array).duplicate()
		if series_profile.is_empty() or grammar.size() < 5:
			push_error("Skill VFX recipe is incomplete: %s" % series_id)
			_recipes.clear()
			return false
		for role in grammar:
			if not GRAMMAR_IDS.has(String(role)):
				push_error("Unknown Skill VFX grammar role: %s" % role)
				_recipes.clear()
				return false
		_recipes[series_id] = {
			"id": series_id,
			"asset_path": String(series_profile.get("asset_path", "")),
			"motion_family": String(series_profile.get("motion_family", "series_lane")),
			"grammar": grammar,
			"base_palette": (BASE_PALETTES.get(series_id, ["ffffff", "7fcfff", "6855ba"]) as Array).duplicate(),
			"impact_primitive": String(DEFAULT_IMPACTS.get(series_id, "wind_burst")),
			"source": (series_profile.get("source", [0, 0]) as Array).duplicate(),
			"target": (series_profile.get("target", [260, 0]) as Array).duplicate(),
			"curve": float(series_profile.get("curve", 0.0)),
		}
	return true


func get_recipe_ids() -> Array:
	return RECIPE_ORDER.duplicate()


func get_grammar_ids() -> Array:
	return GRAMMAR_IDS.duplicate()


func get_recipe(series_id: String) -> Dictionary:
	if _recipes.is_empty():
		load_catalog()
	return (_recipes.get(series_id, {}) as Dictionary).duplicate(true)
