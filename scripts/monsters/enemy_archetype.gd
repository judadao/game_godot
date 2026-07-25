class_name EnemyArchetype
extends Resource

@export var archetype_id: StringName = &"sprout"
@export var display_name: String = "Autumn Sprout"
@export var behavior: StringName = &"chase"
@export var max_health: int = 42
@export var attack_damage: int = 10
@export var defense: int = 1
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
			42, 10, 1, 75.0, 320.0, 60.0, 1.1, 0.35, 18, 5,
			[&"jab"], Color(0.78, 0.32, 0.12), Vector2(0.86, 0.86)
		),
		&"hopper": _make(
			&"hopper", "Leaf Hopper", &"leap",
			34, 11, 0, 110.0, 400.0, 72.0, 0.9, 0.42, 22, 6,
			[&"leap"], Color(0.94, 0.58, 0.12), Vector2(0.78, 0.78)
		),
		&"thornling": _make(
			&"thornling", "Thornling", &"ranged",
			30, 9, 0, 62.0, 520.0, 240.0, 1.35, 0.55, 26, 7,
			[&"thorn_volley"], Color(0.42, 0.62, 0.18), Vector2(0.82, 0.82)
		),
		&"charger": _make(
			&"charger", "Bark Charger", &"charge",
			70, 15, 2, 135.0, 500.0, 82.0, 1.8, 0.7, 35, 10,
			[&"rush"], Color(0.55, 0.25, 0.1), Vector2(1.12, 1.05)
		),
		&"elite": _make(
			&"elite", "Crimson Grove Elite", &"elite",
			150, 20, 4, 95.0, 520.0, 110.0, 1.25, 0.65, 90, 30,
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
