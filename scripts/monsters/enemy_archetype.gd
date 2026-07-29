class_name EnemyArchetype
extends Resource

@export var archetype_id: StringName = &"sprout"
@export var display_name: String = "Autumn Sprout"
@export var behavior: StringName = &"chase"
@export var max_health: int = 30
@export var attack_damage: int = 10
@export var defense: int = 0
@export var speed: float = 75.0
@export var detection_range: float = 320.0
@export var attack_range: float = 60.0
@export var attack_cooldown: float = 1.1
@export var telegraph_time: float = 0.35
@export var experience_reward: int = 18
@export var gold_reward: int = 5
@export var attack_patterns: Array[StringName] = [&"jab"]
@export var visual_color: Color = Color(0.78, 0.32, 0.12, 1.0)
@export var visual_scale: Vector2 = Vector2.ONE


static func autumn_catalog() -> Dictionary:
	return {
		&"sprout": _make(
			&"sprout", "Autumn Sprout", &"chase",
			18, 9, 0, 75.0, 320.0, 60.0, 1.1, 0.35, 1, 5,
			[&"jab"], Color(0.78, 0.32, 0.12), Vector2(0.86, 0.86)
		),
		&"hopper": _make(
			&"hopper", "Leaf Hopper", &"leap",
			16, 10, 0, 110.0, 400.0, 72.0, 0.9, 0.42, 1, 6,
			[&"leap"], Color(0.94, 0.58, 0.12), Vector2(0.78, 0.78)
		),
		&"moth_swarm": _make(
			&"moth_swarm", "Amber Moth Swarm", &"chase",
			10, 6, 0, 145.0, 460.0, 52.0, 0.72, 0.28, 1, 3,
			[&"jab"], Color(1.0, 0.72, 0.16), Vector2(0.58, 0.58)
		),
		&"thornling": _make(
			&"thornling", "Thornling", &"ranged",
			18, 9, 0, 62.0, 520.0, 240.0, 1.35, 0.55, 2, 7,
			[&"thorn_volley"], Color(0.42, 0.62, 0.18), Vector2(0.82, 0.82)
		),
		&"charger": _make(
			&"charger", "Bark Charger", &"charge",
			30, 14, 0, 135.0, 500.0, 82.0, 1.8, 0.7, 3, 10,
			[&"rush"], Color(0.55, 0.25, 0.1), Vector2(1.12, 1.05)
		),
		&"grove_shaman": _make(
			&"grove_shaman", "Grove Shaman", &"ranged",
			24, 12, 0, 58.0, 580.0, 300.0, 1.55, 0.62, 3, 9,
			[&"thorn_volley"], Color(0.38, 0.82, 0.34), Vector2(0.96, 1.08)
		),
		&"elite": _make(
			&"elite", "Crimson Grove Elite", &"elite",
			125, 18, 3, 95.0, 520.0, 110.0, 1.25, 0.65, 12, 30,
			[&"cleave", &"shockwave"], Color(0.75, 0.1, 0.12), Vector2(1.35, 1.3)
		),
	}


static func _make(
	id: StringName,
	name: String,
	behavior_id: StringName,
	health_value: int,
	damage_value: int,
	defense_value: int,
	speed_value: float,
	detection_value: float,
	range_value: float,
	cooldown_value: float,
	telegraph_value: float,
	experience_value: int,
	gold_value: int,
	patterns: Array,
	color_value: Color,
	scale_value: Vector2
) -> EnemyArchetype:
	var result := EnemyArchetype.new()
	result.archetype_id = id
	result.display_name = name
	result.behavior = behavior_id
	result.max_health = health_value
	result.attack_damage = damage_value
	result.defense = defense_value
	result.speed = speed_value
	result.detection_range = detection_value
	result.attack_range = range_value
	result.attack_cooldown = cooldown_value
	result.telegraph_time = telegraph_value
	result.experience_reward = experience_value
	result.gold_reward = gold_value
	result.attack_patterns.clear()
	for pattern in patterns:
		result.attack_patterns.append(pattern as StringName)
	result.visual_color = color_value
	result.visual_scale = scale_value
	return result
