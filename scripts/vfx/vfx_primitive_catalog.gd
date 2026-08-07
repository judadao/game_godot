class_name VFXPrimitiveCatalog
extends RefCounted

const PROFILES := {
	&"fire_loop": {
		"element": &"fire", "motion": &"loop", "one_shot": false,
		"primary": Color("fff1a3"), "secondary": Color("ff5a16"), "accent": Color("851d12"),
		"lifetime": 1.25, "amount": 28, "bounds": Vector2(144.0, 176.0),
		"layers": [&"Glow", &"FireCore", &"OuterFlame", &"Embers", &"Smoke"],
	},
	&"fire_burst": {
		"element": &"fire", "motion": &"burst", "one_shot": true,
		"primary": Color("fff6bf"), "secondary": Color("ff6b16"), "accent": Color("8e170d"),
		"lifetime": 0.72, "amount": 54, "bounds": Vector2(224.0, 224.0),
		"layers": [&"Glow", &"FireCore", &"OuterFlame", &"Embers", &"Smoke"],
	},
	&"fire_trail": {
		"element": &"fire", "motion": &"trail", "one_shot": false,
		"primary": Color("fff0a0"), "secondary": Color("ff4b12"), "accent": Color("72140e"),
		"lifetime": 0.85, "amount": 32, "bounds": Vector2(292.0, 128.0),
		"layers": [&"Glow", &"FireCore", &"OuterFlame", &"Embers", &"Smoke"],
	},
	&"lightning_bolt": {
		"element": &"lightning", "motion": &"bolt", "one_shot": true,
		"primary": Color("f5fbff"), "secondary": Color("73d8ff"), "accent": Color("765cff"),
		"lifetime": 0.24, "amount": 38, "bounds": Vector2(320.0, 144.0),
		"layers": [&"Glow", &"MainBolt", &"BranchBolts", &"Sparks", &"ImpactFlash"],
	},
	&"electric_arc": {
		"element": &"lightning", "motion": &"arc", "one_shot": false,
		"primary": Color("f2fdff"), "secondary": Color("68c8ff"), "accent": Color("8b5dff"),
		"lifetime": 0.82, "amount": 22, "bounds": Vector2(280.0, 176.0),
		"layers": [&"Glow", &"MainBolt", &"BranchBolts", &"Sparks", &"ImpactFlash"],
	},
	&"lightning_impact": {
		"element": &"lightning", "motion": &"impact", "one_shot": true,
		"primary": Color("ffffff"), "secondary": Color("79dcff"), "accent": Color("6d54ff"),
		"lifetime": 0.62, "amount": 58, "bounds": Vector2(224.0, 280.0),
		"layers": [&"Glow", &"MainBolt", &"BranchBolts", &"Sparks", &"ImpactFlash"],
	},
	&"water_stream": {
		"element": &"water", "motion": &"stream", "one_shot": false,
		"primary": Color("d5fbff"), "secondary": Color("36bfe0"), "accent": Color("1766aa"),
		"lifetime": 1.2, "amount": 30, "bounds": Vector2(304.0, 144.0),
		"layers": [&"MainBody", &"Highlight", &"Foam", &"Droplets", &"Mist"],
	},
	&"water_splash": {
		"element": &"water", "motion": &"splash", "one_shot": true,
		"primary": Color("ebffff"), "secondary": Color("48cde7"), "accent": Color("2277b8"),
		"lifetime": 0.78, "amount": 58, "bounds": Vector2(224.0, 192.0),
		"layers": [&"MainBody", &"Highlight", &"Foam", &"Droplets", &"Mist"],
	},
	&"wave_arc": {
		"element": &"water", "motion": &"wave", "one_shot": true,
		"primary": Color("e7ffff"), "secondary": Color("42badc"), "accent": Color("2258a8"),
		"lifetime": 0.82, "amount": 38, "bounds": Vector2(296.0, 216.0),
		"layers": [&"MainBody", &"Highlight", &"Foam", &"Droplets", &"Mist"],
	},
	&"poison_cloud": {
		"element": &"poison", "motion": &"cloud", "one_shot": false,
		"primary": Color("d8ff73"), "secondary": Color("6ecb38"), "accent": Color("3d1468"),
		"lifetime": 1.7, "amount": 42, "bounds": Vector2(244.0, 176.0),
		"layers": [&"MainCloud", &"DarkInnerCloud", &"Bubbles", &"Droplets", &"Corrosion"],
	},
	&"poison_bubble": {
		"element": &"poison", "motion": &"bubble", "one_shot": false,
		"primary": Color("e3ff8d"), "secondary": Color("71d34b"), "accent": Color("57236f"),
		"lifetime": 1.35, "amount": 24, "bounds": Vector2(176.0, 208.0),
		"layers": [&"MainCloud", &"DarkInnerCloud", &"Bubbles", &"Droplets", &"Corrosion"],
	},
	&"poison_splash": {
		"element": &"poison", "motion": &"splash", "one_shot": true,
		"primary": Color("ddff78"), "secondary": Color("6bcf3d"), "accent": Color("48155f"),
		"lifetime": 0.86, "amount": 56, "bounds": Vector2(232.0, 184.0),
		"layers": [&"MainCloud", &"DarkInnerCloud", &"Bubbles", &"Droplets", &"Corrosion"],
	},
	&"ice_mist": {
		"element": &"ice", "motion": &"mist", "one_shot": false,
		"primary": Color("efffff"), "secondary": Color("8edff2"), "accent": Color("5278c4"),
		"lifetime": 1.8, "amount": 36, "bounds": Vector2(260.0, 152.0),
		"layers": [&"Mist", &"CrystalCore", &"Shards", &"Glint", &"ImpactFlash"],
	},
	&"ice_shard": {
		"element": &"ice", "motion": &"shard", "one_shot": true,
		"primary": Color("ffffff"), "secondary": Color("91e8f4"), "accent": Color("4668b6"),
		"lifetime": 0.62, "amount": 26, "bounds": Vector2(276.0, 120.0),
		"layers": [&"Mist", &"CrystalCore", &"Shards", &"Glint", &"ImpactFlash"],
	},
	&"ice_shatter": {
		"element": &"ice", "motion": &"shatter", "one_shot": true,
		"primary": Color("f7ffff"), "secondary": Color("7cd9ee"), "accent": Color("435ab2"),
		"lifetime": 0.82, "amount": 64, "bounds": Vector2(240.0, 224.0),
		"layers": [&"Mist", &"CrystalCore", &"Shards", &"Glint", &"ImpactFlash"],
	},
	&"wind_stream": {
		"element": &"wind", "motion": &"stream", "one_shot": false,
		"primary": Color("f2fff1"), "secondary": Color("91e3b0"), "accent": Color("3c9c92"),
		"lifetime": 1.1, "amount": 26, "bounds": Vector2(316.0, 136.0),
		"layers": [&"Airflow", &"SlashCore", &"Trail", &"Motes", &"ImpactFlash"],
	},
	&"wind_slash": {
		"element": &"wind", "motion": &"slash", "one_shot": true,
		"primary": Color("f6fff0"), "secondary": Color("9be6b2"), "accent": Color("3b918d"),
		"lifetime": 0.52, "amount": 32, "bounds": Vector2(292.0, 180.0),
		"layers": [&"Airflow", &"SlashCore", &"Trail", &"Motes", &"ImpactFlash"],
	},
	&"wind_burst": {
		"element": &"wind", "motion": &"burst", "one_shot": true,
		"primary": Color("f4fff2"), "secondary": Color("8ee4b5"), "accent": Color("398a89"),
		"lifetime": 0.64, "amount": 50, "bounds": Vector2(236.0, 236.0),
		"layers": [&"Airflow", &"SlashCore", &"Trail", &"Motes", &"ImpactFlash"],
	},
}


static func has_profile(effect_id: StringName) -> bool:
	return PROFILES.has(effect_id)


static func get_profile(effect_id: StringName) -> Dictionary:
	return (PROFILES.get(effect_id, {}) as Dictionary).duplicate(true)


static func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for effect_id in PROFILES:
		ids.append(effect_id)
	ids.sort()
	return ids
