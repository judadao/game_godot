class_name ElementTaxonomy
extends RefCounted

const ELEMENTS: Array[String] = [
	"water",
	"fire",
	"wind",
	"lightning",
	"ice",
	"poison",
	"light",
	"dark",
	"normal",
]
const ALIASES := {
	"water": "water",
	"fire": "fire",
	"flame": "fire",
	"wind": "wind",
	"earth": "wind",
	"lightning": "lightning",
	"storm": "lightning",
	"thunder": "lightning",
	"wood": "lightning",
	"ice": "ice",
	"frost": "ice",
	"poison": "poison",
	"venom": "poison",
	"light": "light",
	"holy": "light",
	"celestial": "light",
	"dark": "dark",
	"shadow": "dark",
	"echo": "dark",
	"normal": "normal",
	"neutral": "normal",
	"physical": "normal",
}
const EFFECT_PROFILES := {
	"water": {
		"element": "water", "effect_id": "tidal_splash", "icon": "≈",
		"name": "潮濺", "description": "攻擊額外波及 1 個目標；貫穿劍氣加寬 20%。",
		"target_count_bonus": 1, "projectile_count_bonus": 1,
		"sweep_width_multiplier": 1.20,
	},
	"fire": {
		"element": "fire", "effect_id": "burn", "icon": "▲",
		"name": "灼燒", "description": "命中後附加短時間火焰持續傷害。",
		"burn_damage": 1, "burn_duration": 2.0,
	},
	"wind": {
		"element": "wind", "effect_id": "gust_launch", "icon": "≫",
		"name": "風壓", "description": "命中的擊退力提高 30%。",
		"knockback_multiplier": 1.30,
	},
	"lightning": {
		"element": "lightning", "effect_id": "shock", "icon": "ϟ",
		"name": "感電", "description": "命中造成 0.12 秒短暫暈眩。",
		"combo_stun": 0.12,
	},
	"ice": {
		"element": "ice", "effect_id": "chill", "icon": "✦",
		"name": "寒意", "description": "命中使移動速度降低 15%，持續 1.5 秒。",
		"frost_ratio": 0.15, "frost_duration": 1.5,
	},
	"poison": {
		"element": "poison", "effect_id": "venom", "icon": "◆",
		"name": "中毒", "description": "命中附加 3 秒毒性持續傷害。",
		"poison_damage": 1, "poison_duration": 3.0,
	},
	"light": {
		"element": "light", "effect_id": "radiant_mend", "icon": "☼",
		"name": "輝癒", "description": "依命中總傷害恢復 3% 生命。",
		"heal_on_hit_ratio": 0.03,
	},
	"dark": {
		"element": "dark", "effect_id": "shadow_drain", "icon": "●",
		"name": "蝕命", "description": "獲得 4% 傷害生命竊取。",
		"lifesteal_ratio": 0.04,
	},
	"normal": {
		"element": "normal", "effect_id": "true_edge", "icon": "◇",
		"name": "真鋒", "description": "攻擊暴擊率提高 4%。",
		"critical_chance": 0.04,
	},
}


func get_all() -> Array[String]:
	return ELEMENTS.duplicate()


func normalize(value: String, fallback: String = "") -> String:
	var candidate := value.strip_edges().to_lower()
	if ALIASES.has(candidate):
		return String(ALIASES[candidate])
	return fallback if fallback in ELEMENTS else ""


func is_valid(value: String) -> bool:
	return value in ELEMENTS


func get_effect_profile(value: String) -> Dictionary:
	var element := normalize(value, "normal")
	return (EFFECT_PROFILES.get(element, {}) as Dictionary).duplicate(true)


func get_effect_summary(value: String) -> String:
	var profile := get_effect_profile(value)
	if profile.is_empty():
		return ""
	return "%s %s：%s" % [
		String(profile.get("icon", "◇")),
		String(profile.get("name", "屬性效果")),
		String(profile.get("description", "")),
	]


func get_interaction_multiplier(_attacker_element: String, _defender_element: String) -> float:
	return 1.0


func apply_attack_side_effects(base_effect: Dictionary, elements: Array) -> Dictionary:
	var result := base_effect.duplicate(true)
	var canonical_elements: Array[String] = []
	var side_effect_ids: Array[String] = []
	for element_variant in elements:
		var element := normalize(String(element_variant))
		if element.is_empty() or canonical_elements.has(element):
			continue
		canonical_elements.append(element)
		var profile := get_effect_profile(element)
		side_effect_ids.append(String(profile.get("effect_id", "")))
		if profile.has("target_count_bonus"):
			result["target_count"] = maxi(
				1,
				int(result.get("target_count", 1)) + int(profile["target_count_bonus"])
			)
		if profile.has("projectile_count_bonus"):
			result["projectile_count"] = maxi(
				1,
				int(result.get("projectile_count", result.get("projectiles", 1)))
					+ int(profile["projectile_count_bonus"])
			)
			result["direction_count"] = maxi(
				int(result.get("direction_count", 1)), int(result["projectile_count"])
			)
		if profile.has("burn_damage"):
			result["burn_damage"] = maxi(
				int(result.get("burn_damage", 0)), int(profile["burn_damage"])
			)
			result["burn_duration"] = maxf(
				float(result.get("burn_duration", 0.0)), float(profile["burn_duration"])
			)
		if profile.has("knockback_multiplier"):
			result["knockback_multiplier"] = maxf(
				float(result.get("knockback_multiplier", 1.0)),
				float(profile["knockback_multiplier"])
			)
		if profile.has("combo_stun"):
			result["combo_stun"] = maxf(
				float(result.get("combo_stun", 0.0)), float(profile["combo_stun"])
			)
		if profile.has("frost_ratio"):
			result["frost_ratio"] = maxf(
				float(result.get("frost_ratio", 0.0)), float(profile["frost_ratio"])
			)
			result["frost_duration"] = maxf(
				float(result.get("frost_duration", 0.0)), float(profile["frost_duration"])
			)
		if profile.has("poison_damage"):
			result["poison_damage"] = maxi(
				int(result.get("poison_damage", 0)), int(profile["poison_damage"])
			)
			result["poison_duration"] = maxf(
				float(result.get("poison_duration", 0.0)), float(profile["poison_duration"])
			)
		if profile.has("heal_on_hit_ratio"):
			result["heal_on_hit_ratio"] = (
				float(result.get("heal_on_hit_ratio", 0.0))
				+ float(profile["heal_on_hit_ratio"])
			)
		if profile.has("lifesteal_ratio"):
			result["lifesteal_ratio"] = (
				float(result.get("lifesteal_ratio", 0.0))
				+ float(profile["lifesteal_ratio"])
			)
		if profile.has("critical_chance"):
			result["critical_chance"] = clampf(
				float(result.get("critical_chance", 0.0))
					+ float(profile["critical_chance"]),
				0.0,
				1.0
			)
	result["elements"] = canonical_elements
	result["element_side_effects"] = side_effect_ids
	return result


func get_color(value: String) -> Color:
	match normalize(value, "normal"):
		"water":
			return Color("#36b8ff")
		"fire":
			return Color("#ff5a24")
		"wind":
			return Color("#76efcf")
		"lightning":
			return Color("#a986ff")
		"ice":
			return Color("#8eeaff")
		"poison":
			return Color("#85dc3f")
		"light":
			return Color("#ffe991")
		"dark":
			return Color("#9b69d9")
		_:
			return Color("#dce9f2")
