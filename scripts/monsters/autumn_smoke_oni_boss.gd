class_name AutumnSmokeOniBoss
extends "res://scripts/monsters/autumn_guardian.gd"

@onready var jaw_pivot: Node2D = get_node_or_null("Visual/HeadPivot/JawPivot") as Node2D
@onready var eye_fire: Node2D = get_node_or_null("Visual/HeadPivot/EyeFire") as Node2D
@onready var jaw_core_weak_point: Area2D = get_node_or_null("Visual/HeadPivot/JawCoreWeakPoint") as Area2D
@onready var jaw_core_flame: Node2D = get_node_or_null("Visual/HeadPivot/JawCoreWeakPoint/CoreFlame") as Node2D
@onready var arm_pivots: Array[Node] = get_node("Visual").get_children().filter(
	func(child: Node) -> bool: return child.name.begins_with("Arm")
)

var _puppet_time := 0.0
var _arm_rest_rotations: Array[float] = []
const JAW_CLOSED_Y := 128.0
const JAW_OPEN_DISTANCE := 18.0


func _ready() -> void:
	gravity = 0.0
	navigation_jump_velocity = 0.0
	velocity = Vector2.ZERO
	super._ready()
	var shoulder_positions: Array[Vector2] = [
		Vector2(-86, -729), Vector2(86, -729),
		Vector2(-86, -671), Vector2(86, -671),
		Vector2(-86, -610), Vector2(86, -610),
	]
	# Authoritative sketch pose: raised guard, horizontal threat, crossed execution blades.
	var shoulder_rotations: Array[float] = [0.45, -0.45, 0.10, -0.10, -0.45, 0.45]
	var elbow_rotations: Array[float] = [-0.25, 0.25, -0.10, 0.10, -1.95, 1.95]
	var wrist_rotations: Array[float] = [-0.20, 0.20, -PI * 0.5, PI * 0.5, 2.40, -2.40]
	var hand_anchor_offsets: Array[Vector2] = [
		Vector2(-56, -196), Vector2(56, -196),
		Vector2(-56, -196), Vector2(56, -196),
		Vector2(-113, 127), Vector2(113, 127),
	]
	var upper_art_offsets: Array[Vector2] = [
		Vector2(-28, -26), Vector2(-14, -27),
		Vector2(-28, -26), Vector2(-14, -27),
		Vector2(-28, -26), Vector2(-14, -27),
	]
	var forearm_art_offsets: Array[Vector2] = [
		Vector2(6, -42), Vector2(6, -27),
		Vector2(6, -42), Vector2(6, -27),
		Vector2(6, -42), Vector2(6, -27),
	]
	for index in mini(arm_pivots.size(), shoulder_positions.size()):
		var arm := arm_pivots[index] as Node2D
		var side := -1.0 if index % 2 == 0 else 1.0
		arm.position = shoulder_positions[index]
		arm.rotation = shoulder_rotations[index]
		_arm_rest_rotations.append(shoulder_rotations[index])
		var upper := arm.get_node("UpperArm") as Sprite2D
		var elbow := arm.get_node("ElbowPivot") as Node2D
		var forearm := elbow.get_node("Forearm") as Sprite2D
		var wrist := elbow.get_node("WristPivot") as Node2D
		var hand := wrist.get_node("HandKatana") as Sprite2D
		upper.position = Vector2(side * 86.0, 0.0)
		upper.rotation = -side * PI * 0.5
		upper.scale = Vector2.ONE * 0.52
		upper.offset = upper_art_offsets[index]
		elbow.position = Vector2(side * 172.0, 0.0)
		elbow.rotation = elbow_rotations[index]
		forearm.position = Vector2(side * 82.0, 0.0)
		forearm.rotation = -side * PI * 0.5
		forearm.scale = Vector2.ONE * 0.52
		forearm.offset = forearm_art_offsets[index]
		wrist.position = Vector2(side * 164.0, 0.0)
		wrist.rotation = wrist_rotations[index]
		hand.position = Vector2.ZERO
		hand.offset = hand_anchor_offsets[index]
		hand.scale = Vector2.ONE * 0.56
		hand.z_index = 4


func _process(delta: float) -> void:
	_puppet_time += delta
	if jaw_pivot != null:
		var open_amount := (sin(_puppet_time * 2.2) + 1.0) * 0.5
		jaw_pivot.rotation = 0.0
		jaw_pivot.position.y = JAW_CLOSED_Y + open_amount * JAW_OPEN_DISTANCE
		var core_exposed := open_amount >= 0.55
		if jaw_core_weak_point != null:
			jaw_core_weak_point.collision_layer = 16 if core_exposed else 0
		if jaw_core_flame != null:
			jaw_core_flame.visible = core_exposed
			jaw_core_flame.scale = Vector2.ONE * (0.92 + open_amount * 0.16)
	if eye_fire != null:
		var flame_pulse := 0.94 + sin(_puppet_time * 8.0) * 0.06
		eye_fire.scale = Vector2.ONE * flame_pulse
	for index in arm_pivots.size():
		var arm := arm_pivots[index] as Node2D
		if arm != null:
			arm.rotation = _arm_rest_rotations[index] + sin(_puppet_time * 1.15 + float(index) * 0.72) * 0.035


func _build_guardian_archetype() -> Resource:
	var result := super._build_guardian_archetype()
	result.set("display_name", "青燐六臂骸武者")
	result.set("visual_color", Color.WHITE)
	result.set("visual_scale", Vector2(0.58, 0.58))
	return result
