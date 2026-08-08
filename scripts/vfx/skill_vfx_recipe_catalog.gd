class_name SkillVFXRecipeCatalog
extends RefCounted

const SERIES_CATALOG_SCRIPT := preload("res://scripts/systems/skill_series_vfx_catalog.gd")
const MATERIAL_COMPOSITION_PATH := "res://data/skill_series_raster_composition.json"
const GRAMMAR_IDS := [
	"core", "trail", "arc", "beam", "bolt", "ring", "burst", "impact",
	"projectile", "orbit", "rain", "aura", "ground_zone", "afterimage",
	"distortion",
]
const RECIPE_ORDER := [
	"sword_rain", "moon_wheel", "feather", "thorn", "dr_stone",
	"black_hole", "fire", "lightning", "water_flow", "arcane_swamp",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const RECIPE_GRAMMAR := {
	"sword_rain": ["core", "rain", "projectile", "trail", "impact", "ring"],
	"moon_wheel": ["core", "orbit", "projectile", "trail", "ring", "impact"],
	"feather": ["core", "projectile", "trail", "afterimage", "ring", "impact"],
	"thorn": ["core", "ground_zone", "aura", "projectile", "trail", "impact", "burst"],
	"dr_stone": ["core", "orbit", "projectile", "trail", "burst", "impact", "afterimage"],
	"black_hole": ["core", "distortion", "ring", "aura", "trail", "impact", "burst"],
	"fire": ["core", "projectile", "trail", "distortion", "burst", "impact", "ground_zone"],
	"lightning": ["core", "bolt", "beam", "trail", "ring", "impact", "burst"],
	"water_flow": ["core", "arc", "trail", "projectile", "ring", "impact", "ground_zone"],
	"arcane_swamp": ["core", "ground_zone", "aura", "ring", "trail", "impact", "distortion"],
	"dragon_breath": ["core", "beam", "trail", "distortion", "ring", "impact", "burst"],
	"dawn_vitality": ["core", "aura", "ring", "rain", "impact", "ground_zone"],
	"shared_branch_vitality": ["core", "beam", "aura", "afterimage", "ring", "impact", "ground_zone"],
}
const BASE_PALETTES := {
	"sword_rain": ["ecfbff", "79cfff", "6f72ff"],
	"moon_wheel": ["fffbe2", "a8c9ff", "7162d8"],
	"feather": ["fffce8", "f6d982", "9a72e8"],
	"thorn": ["f5ffc2", "7fd05e", "6b285f"],
	"dr_stone": ["fff0c5", "c3935f", "5e4b43"],
	"black_hole": ["fff7ff", "9a6cff", "160b2d"],
	"fire": ["fff0a0", "ff641d", "8c1811"],
	"lightning": ["f7ffff", "6fdcff", "765cff"],
	"water_flow": ["e9ffff", "49c8e8", "2267b2"],
	"arcane_swamp": ["d8ffad", "5c9c69", "34204f"],
	"dragon_breath": ["fff1ff", "b36cff", "47237f"],
	"dawn_vitality": ["fff7b8", "ffbe55", "d8673d"],
	"shared_branch_vitality": ["f3ffd0", "8cd071", "3d765c"],
}
const DEFAULT_IMPACTS := {
	"sword_rain": "lightning_impact",
	"moon_wheel": "wind_burst",
	"feather": "wind_burst",
	"thorn": "poison_splash",
	"dr_stone": "wind_burst",
	"black_hole": "lightning_impact",
	"fire": "fire_burst",
	"lightning": "lightning_impact",
	"water_flow": "water_splash",
	"arcane_swamp": "poison_splash",
	"dragon_breath": "fire_burst",
	"dawn_vitality": "wind_burst",
	"shared_branch_vitality": "wind_burst",
}

var _series_catalog: RefCounted = SERIES_CATALOG_SCRIPT.new()
var _recipes: Dictionary = {}
var _material_compositions: Dictionary = {}
var _blessing_material_compositions: Dictionary = {}


func load_catalog() -> bool:
	_recipes.clear()
	_material_compositions.clear()
	_blessing_material_compositions.clear()
	if not bool(_series_catalog.call("load_catalog")):
		return false
	if not _load_material_compositions():
		return false
	for series_id in RECIPE_ORDER:
		var series_profile := _series_catalog.call("get_profile", series_id) as Dictionary
		var grammar := (RECIPE_GRAMMAR.get(series_id, []) as Array).duplicate()
		if series_profile.is_empty() or grammar.size() < 5:
			push_error("Skill VFX recipe is incomplete: %s" % series_id)
			_recipes.clear()
			return false
		if not _material_compositions.has(series_id):
			push_error("Skill VFX recipe lacks raster composition mapping: %s" % series_id)
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
			"material_asset_path": String(series_profile.get("material_asset_path", "")),
			"material_runtime": (series_profile.get("material_runtime", {}) as Dictionary).duplicate(true),
			"material_composition": (_material_compositions[series_id] as Dictionary).duplicate(true),
			"blessing_material_compositions": _blessing_material_compositions.duplicate(true),
			"procedural_core": bool(series_profile.get("procedural_core", false)),
			"motion_family": String(series_profile.get("motion_family", "series_lane")),
			"grammar": grammar,
			"base_palette": (BASE_PALETTES.get(series_id, ["ffffff", "7fcfff", "6855ba"]) as Array).duplicate(),
			"impact_primitive": String(DEFAULT_IMPACTS.get(series_id, "wind_burst")),
			"source": (series_profile.get("source", [0, 0]) as Array).duplicate(),
			"target": (series_profile.get("target", [260, 0]) as Array).duplicate(),
			"curve": float(series_profile.get("curve", 0.0)),
			"specialized_renderer": _specialized_renderer(series_id),
		}
	return true


func _load_material_compositions() -> bool:
	if not FileAccess.file_exists(MATERIAL_COMPOSITION_PATH):
		push_error("Skill raster composition catalog not found: %s" % MATERIAL_COMPOSITION_PATH)
		return false
	var file := FileAccess.open(MATERIAL_COMPOSITION_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var catalog := parsed as Dictionary
	if int(catalog.get("schema_version", 0)) != 1 or String(catalog.get("status", "")) != "runtime_wired":
		push_error("Skill raster composition catalog must be schema 1 and runtime_wired.")
		return false
	var canvas := catalog.get("source_canvas", {}) as Dictionary
	var canvas_size := Vector2i(int(canvas.get("width", 0)), int(canvas.get("height", 0)))
	if canvas_size.x <= 0 or canvas_size.y <= 0:
		return false
	for entry_variant in catalog.get("series", []) as Array:
		if not entry_variant is Dictionary:
			return false
		var entry := entry_variant as Dictionary
		if not _validate_material_composition(entry, canvas_size):
			return false
		_material_compositions[String(entry.get("id", ""))] = entry.duplicate(true)
	for entry_variant in catalog.get("blessing_overlays", []) as Array:
		if not entry_variant is Dictionary:
			return false
		var entry := entry_variant as Dictionary
		if not _validate_material_composition(entry, canvas_size):
			return false
		_blessing_material_compositions[String(entry.get("id", ""))] = entry.duplicate(true)
	if _material_compositions.size() != RECIPE_ORDER.size() or _blessing_material_compositions.size() != 8:
		push_error("Skill raster composition catalog must map 13 series and eight Blessings.")
		return false
	return true


func _validate_material_composition(composition: Dictionary, canvas_size: Vector2i) -> bool:
	var composition_id := String(composition.get("id", "")).strip_edges()
	var asset_path := String(composition.get("asset_path", "")).strip_edges()
	if composition_id.is_empty() or asset_path.is_empty() or not ResourceLoader.exists(asset_path, "Texture2D"):
		return false
	var components_value: Variant = composition.get("components", null)
	if not components_value is Array or (components_value as Array).is_empty():
		return false
	var component_ids: Dictionary = {}
	for component_variant in components_value as Array:
		if not component_variant is Dictionary:
			return false
		var component := component_variant as Dictionary
		var component_id := String(component.get("id", "")).strip_edges()
		var region_value: Variant = component.get("region", null)
		if component_id.is_empty() or component_ids.has(component_id) or not region_value is Array or (region_value as Array).size() != 4:
			return false
		var region := region_value as Array
		var rect := Rect2i(int(region[0]), int(region[1]), int(region[2]), int(region[3]))
		if rect.position.x < 0 or rect.position.y < 0 or rect.size.x <= 0 or rect.size.y <= 0 or rect.end.x > canvas_size.x or rect.end.y > canvas_size.y or rect.size.x >= canvas_size.x or rect.size.y >= canvas_size.y:
			return false
		var component_path := String(component.get("asset_path", ""))
		var asset_region_value: Variant = component.get("asset_region", null)
		if component_path.is_empty() or not ResourceLoader.exists(component_path, "Texture2D") or not asset_region_value is Array or (asset_region_value as Array).size() != 4:
			return false
		var component_texture := load(component_path) as Texture2D
		if component_texture == null:
			return false
		var asset_region := asset_region_value as Array
		var asset_rect := Rect2i(int(asset_region[0]), int(asset_region[1]), int(asset_region[2]), int(asset_region[3]))
		var component_size := Vector2i(component_texture.get_size())
		if asset_rect.position.x < 0 or asset_rect.position.y < 0 or asset_rect.size.x <= 0 or asset_rect.size.y <= 0 or asset_rect.end.x > component_size.x or asset_rect.end.y > component_size.y:
			return false
		component_ids[component_id] = true
	var phases: Dictionary = {}
	for stage_variant in composition.get("stages", []) as Array:
		if not stage_variant is Dictionary:
			return false
		var stage := stage_variant as Dictionary
		var phase := String(stage.get("phase", ""))
		if not phase in ["anticipation", "travel", "contact", "residual"] or phases.has(phase):
			return false
		phases[phase] = true
		for layer_variant in stage.get("layers", []) as Array:
			if not layer_variant is Dictionary:
				return false
			var layer := layer_variant as Dictionary
			if not component_ids.has(String(layer.get("component", ""))) or String(layer.get("anchor", "")).is_empty() or String(layer.get("placement", "")).is_empty():
				return false
			if not layer.get("offset", null) is Array or (layer.get("offset", []) as Array).size() != 2 or not layer.get("scale", null) is Array or (layer.get("scale", []) as Array).size() != 2:
				return false
			if not ["mix", "add"].has(String(layer.get("blend", ""))) or float(layer.get("lifetime_seconds", 0.0)) <= 0.0:
				return false
			var stack := layer.get("stack", {}) as Dictionary
			if String(stack.get("mode", "")).is_empty():
				return false
			var tier_counts := stack.get("count_by_tier", {}) as Dictionary
			for tier_id in ["basic", "advanced", "master"]:
				if int(tier_counts.get(tier_id, 0)) <= 0:
					return false
	return phases.size() == 4


func _specialized_renderer(series_id: String) -> String:
	match series_id:
		"sword_rain": return "sword_rain_material_cadence"
		"moon_wheel": return "bouncing_moon_wheel_field"
		"feather": return "persistent_feather_halo"
		"thorn": return "thorn_emerge_bloom_barrage"
		"dr_stone": return "blessing_mutable_stone_drone_squad"
		"black_hole": return "layered_black_hole"
		"arcane_swamp": return "blessing_mutable_arcane_swamp"
		"fire": return "staggered_fire_pillar_field"
		"lightning": return "residual_chain_sky_strike"
		"water_flow": return "layered_tidal_push"
		"dragon_breath": return "layered_dragon_breath_sweep"
		"dawn_vitality": return "player_following_healing_zone"
		"shared_branch_vitality": return "body_overdrive_aura_afterimage"
	return ""


func get_recipe_ids() -> Array:
	return RECIPE_ORDER.duplicate()


func get_grammar_ids() -> Array:
	return GRAMMAR_IDS.duplicate()


func get_recipe(series_id: String) -> Dictionary:
	if _recipes.is_empty():
		load_catalog()
	return (_recipes.get(series_id, {}) as Dictionary).duplicate(true)
