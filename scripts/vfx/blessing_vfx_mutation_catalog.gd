class_name BlessingVFXMutationCatalog
extends RefCounted

const MUTATIONS := {
	"fire": {
		"shape": "turbulent_flare", "count_bonus": 1, "trajectory": 0.12,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/fire_overlay_v1.png",
		"palette": ["fff2a0", "ff621c", "8b1710"],
		"trail": "fire_trail", "impact": "fire_burst", "ground": "fire_loop",
	},
	"lightning": {
		"shape": "forked_snap", "count_bonus": 2, "trajectory": 0.24,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/lightning_overlay_v1.png",
		"palette": ["f8ffff", "73dcff", "795cff"],
		"trail": "electric_arc", "impact": "lightning_impact", "ground": "electric_arc",
	},
	"water": {
		"shape": "returning_wave", "count_bonus": 1, "trajectory": 0.16,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/water_overlay_v1.png",
		"palette": ["e8ffff", "43c8e8", "2264b0"],
		"trail": "water_stream", "impact": "water_splash", "ground": "wave_arc",
	},
	"poison": {
		"shape": "corrosive_split", "count_bonus": 1, "trajectory": 0.18,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/poison_overlay_v1.png",
		"palette": ["e3ff7a", "6fd246", "4f176b"],
		"trail": "poison_bubble", "impact": "poison_splash", "ground": "poison_cloud",
	},
	"ice": {
		"shape": "crystal_shard", "count_bonus": 1, "trajectory": 0.10,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/ice_overlay_v1.png",
		"palette": ["f5ffff", "8ce5f3", "4968ba"],
		"trail": "ice_mist", "impact": "ice_shatter", "ground": "ice_mist",
	},
	"wind": {
		"shape": "crescent_stream", "count_bonus": 2, "trajectory": 0.30,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/wind_overlay_v1.png",
		"palette": ["f3fff0", "91e4b2", "3a918c"],
		"trail": "wind_stream", "impact": "wind_burst", "ground": "wind_slash",
	},
	"light": {
		"shape": "radiant_halo", "count_bonus": 1, "trajectory": 0.08,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/light_overlay_v1.png",
		"palette": ["ffffff", "ffe59b", "d58c49"],
		"trail": "wind_stream", "impact": "lightning_impact", "ground": "wind_burst",
	},
	"dark": {
		"shape": "void_echo", "count_bonus": 2, "trajectory": 0.26,
		"overlay_asset_path": "res://assets/generated/vfx/skill_materials/blessings/dark_overlay_v1.png",
		"palette": ["f1d8ff", "9b54d8", "2a123d"],
		"trail": "poison_cloud", "impact": "poison_splash", "ground": "poison_cloud",
	},
}


static func get_mutation(element: String) -> Dictionary:
	return (MUTATIONS.get(element.to_lower(), {}) as Dictionary).duplicate(true)


static func get_elements() -> Array[String]:
	var result: Array[String] = []
	for element in MUTATIONS:
		result.append(String(element))
	result.sort()
	return result
