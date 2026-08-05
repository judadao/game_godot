class_name AutumnSixArmColossusBoss
extends "res://scripts/monsters/autumn_guardian.gd"

const JAW_CLOSED_Y := 116.0
const JAW_OPEN_DISTANCE := 30.0
const CORE_EXPOSE_THRESHOLD := 0.56

@onready var jaw_pivot: Node2D = get_node("Visual/Core/HeadPivot/JawPivot") as Node2D
@onready var eye_fire: Node2D = get_node("Visual/SpiritFire/EyeFire") as Node2D
@onready var jaw_core_weak_point: Area2D = get_node("Visual/SpiritFire/JawCoreWeakPoint") as Area2D
@onready var jaw_core_flame: Node2D = get_node("Visual/SpiritFire/JawCoreFlame") as Node2D
@onready var arm_pivots: Array[Node] = get_node("Visual/Armature").get_children().filter(
	func(child: Node) -> bool: return child.name.begins_with("Arm")
)

var _presentation_time := 0.0
var _arm_rest_rotations: Array[float] = []


func _ready() -> void:
	gravity = 0.0
	navigation_jump_velocity = 0.0
	velocity = Vector2.ZERO
	super._ready()
	for arm_variant in arm_pivots:
		_arm_rest_rotations.append((arm_variant as Node2D).rotation)


func _process(delta: float) -> void:
	_presentation_time += delta
	var open_amount := (sin(_presentation_time * 1.7 - PI * 0.5) + 1.0) * 0.5
	jaw_pivot.rotation = 0.0
	jaw_pivot.position.y = JAW_CLOSED_Y + open_amount * JAW_OPEN_DISTANCE
	var core_exposed := open_amount >= CORE_EXPOSE_THRESHOLD
	jaw_core_weak_point.collision_layer = 16 if core_exposed else 0
	jaw_core_flame.visible = core_exposed
	jaw_core_flame.scale = Vector2.ONE * (0.92 + open_amount * 0.14)
	eye_fire.scale = Vector2.ONE * (0.96 + sin(_presentation_time * 7.0) * 0.04)
	for index in arm_pivots.size():
		var arm := arm_pivots[index] as Node2D
		arm.rotation = _arm_rest_rotations[index] + sin(
			_presentation_time * 0.8 + float(index) * 0.9
		) * 0.018


func _build_guardian_archetype() -> Resource:
	var result := super._build_guardian_archetype()
	result.set("display_name", "青燐六臂骸武神")
	result.set("visual_color", Color.WHITE)
	result.set("visual_scale", Vector2.ONE)
	return result
