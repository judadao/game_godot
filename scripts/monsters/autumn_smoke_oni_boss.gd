class_name AutumnSmokeOniBoss
extends "res://scripts/monsters/autumn_guardian.gd"

@onready var jaw_pivot: Node2D = get_node_or_null("Visual/HeadPivot/JawPivot") as Node2D
@onready var eye_fire: Node2D = get_node_or_null("Visual/HeadPivot/EyeFire") as Node2D
@onready var jaw_core_weak_point: Area2D = get_node_or_null("Visual/HeadPivot/JawCoreWeakPoint") as Area2D
@onready var jaw_core_flame: Node2D = get_node_or_null("Visual/HeadPivot/JawCoreWeakPoint/CoreFlame") as Node2D
@onready var visual_root: Node2D = get_node("Visual") as Node2D
@onready var arm_pivots: Array[Node] = get_node("Visual").get_children().filter(
	func(child: Node) -> bool: return child.name.begins_with("Arm")
)

var _puppet_time := 0.0
var _arm_rest_rotations: Array[float] = []
var _boss_animation := &"idle"
var _animation_time := 0.0
var _visual_rest_position := Vector2.ZERO
const JAW_CLOSED_Y := 128.0
const JAW_OPEN_DISTANCE := 18.0
const BOSS_ANIMATIONS := {
	&"idle": {"duration": 2.4, "loop": true},
	&"six_arm_slash": {"duration": 1.25, "loop": false},
	&"cross_execution": {"duration": 1.5, "loop": false},
	&"skull_flame_summon": {"duration": 2.0, "loop": false},
	&"phase_shift": {"duration": 1.1, "loop": false},
	&"hurt": {"duration": 0.45, "loop": false},
	&"death": {"duration": 2.8, "loop": false},
}


func _ready() -> void:
	gravity = 0.0
	navigation_jump_velocity = 0.0
	velocity = Vector2.ZERO
	super._ready()
	_visual_rest_position = visual_root.position
	var shoulder_positions: Array[Vector2] = [
		Vector2(-18, -565), Vector2(18, -565),
		Vector2(-22, -505), Vector2(22, -505),
		Vector2(-28, -445), Vector2(28, -445),
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
		upper.position = Vector2(side * -8.0, 0.0)
		upper.rotation = -side * PI * 0.5
		upper.scale = Vector2.ONE * 0.72
		upper.offset = Vector2.ZERO
		elbow.position = Vector2(side * 105.0, 0.0)
		elbow.rotation = elbow_rotations[index]
		forearm.position = Vector2(side * 35.0, 0.0)
		forearm.rotation = -side * PI * 0.5
		forearm.scale = Vector2.ONE * 0.62
		forearm.offset = Vector2.ZERO
		wrist.position = Vector2(side * 115.0, 0.0)
		wrist.rotation = wrist_rotations[index]
		hand.position = Vector2.ZERO
		hand.offset = hand_anchor_offsets[index]
		hand.scale = Vector2.ONE * 0.56
		hand.z_index = 4
	_apply_boss_pose()


func _process(delta: float) -> void:
	advance_boss_animation(delta)


func play_boss_animation(animation_id: StringName) -> bool:
	if not BOSS_ANIMATIONS.has(animation_id):
		return false
	_boss_animation = animation_id
	_animation_time = 0.0
	_apply_boss_pose()
	return true


func advance_boss_animation(delta: float) -> void:
	_puppet_time += delta
	_animation_time += maxf(delta, 0.0)
	var spec := BOSS_ANIMATIONS[_boss_animation] as Dictionary
	var duration := float(spec.get("duration", 1.0))
	_animation_time = fmod(_animation_time, duration) if bool(spec.get("loop", false)) else minf(_animation_time, duration)
	_apply_boss_pose()


func get_boss_animation_snapshot() -> Dictionary:
	var rotations: Array[float] = []
	for pivot in arm_pivots:
		rotations.append((pivot as Node2D).rotation)
	return {
		"animation": _boss_animation,
		"time": _animation_time,
		"arm_rotations": rotations,
		"jaw_y": jaw_pivot.position.y if jaw_pivot != null else JAW_CLOSED_Y,
		"core_exposed": jaw_core_flame.visible if jaw_core_flame != null else false,
		"visual_position": visual_root.position,
		"visual_modulate": visual_root.modulate,
	}


func _apply_boss_pose() -> void:
	if _arm_rest_rotations.size() < arm_pivots.size():
		return
	var spec := BOSS_ANIMATIONS[_boss_animation] as Dictionary
	var duration := maxf(float(spec.get("duration", 1.0)), 0.01)
	var phase := clampf(_animation_time / duration, 0.0, 1.0)
	var jaw_open := (sin(_puppet_time * 2.2) + 1.0) * 0.18
	var pulse := 0.94 + sin(_puppet_time * 8.0) * 0.06
	visual_root.position = _visual_rest_position
	visual_root.rotation = 0.0
	visual_root.modulate = Color.WHITE
	for index in arm_pivots.size():
		var arm := arm_pivots[index] as Node2D
		arm.rotation = _arm_rest_rotations[index] + sin(_puppet_time * 1.15 + float(index) * 0.72) * 0.035
	match _boss_animation:
		&"six_arm_slash":
			for index in arm_pivots.size():
				var arm := arm_pivots[index] as Node2D
				var side := -1.0 if index % 2 == 0 else 1.0
				var stagger := clampf(phase * 1.55 - float(index / 2) * 0.18, 0.0, 1.0)
				arm.rotation = _arm_rest_rotations[index] + side * sin(stagger * PI) * (1.05 + float(index / 2) * 0.18)
			jaw_open = sin(phase * PI) * 0.65
		&"cross_execution":
			var cross_amount := sin(phase * PI)
			for index in arm_pivots.size():
				var arm := arm_pivots[index] as Node2D
				var side := -1.0 if index % 2 == 0 else 1.0
				arm.rotation = _arm_rest_rotations[index] - side * cross_amount * (0.55 + float(index / 2) * 0.28)
			jaw_open = cross_amount * 0.9
		&"skull_flame_summon":
			var summon := sin(phase * PI)
			jaw_open = 0.35 + summon * 0.65
			pulse = 1.0 + summon * 0.42 + sin(_puppet_time * 18.0) * 0.08
			for index in arm_pivots.size():
				var arm := arm_pivots[index] as Node2D
				var side := -1.0 if index % 2 == 0 else 1.0
				arm.rotation = _arm_rest_rotations[index] + side * summon * (0.22 + float(index / 2) * 0.13)
		&"phase_shift":
			var shift := sin(phase * PI)
			visual_root.position.x += sin(phase * PI * 8.0) * 12.0
			visual_root.modulate = Color(0.55, 0.92, 1.0, 1.0 - shift * 0.48)
			pulse = 1.0 + shift * 0.55
		&"hurt":
			var recoil := (1.0 - phase) * sin(phase * PI * 5.0)
			visual_root.position.x += recoil * 18.0
			visual_root.rotation = recoil * 0.025
			visual_root.modulate = Color(0.6, 0.9, 1.0)
			jaw_open = 0.7 * (1.0 - phase)
		&"death":
			var fall := phase * phase
			visual_root.position.y += fall * 170.0
			visual_root.rotation = fall * 0.12
			visual_root.modulate = Color(0.45, 0.75, 1.0, 1.0 - phase * 0.86)
			for index in arm_pivots.size():
				var arm := arm_pivots[index] as Node2D
				var side := -1.0 if index % 2 == 0 else 1.0
				arm.rotation = _arm_rest_rotations[index] + side * phase * (0.8 + float(index / 2) * 0.2)
			jaw_open = 1.0
		_:
			pass
	if jaw_pivot != null:
		jaw_pivot.rotation = 0.0
		jaw_pivot.position.y = JAW_CLOSED_Y + clampf(jaw_open, 0.0, 1.0) * JAW_OPEN_DISTANCE
	var core_exposed := jaw_open >= 0.55
	if jaw_core_weak_point != null:
		jaw_core_weak_point.collision_layer = 16 if core_exposed else 0
	if jaw_core_flame != null:
		jaw_core_flame.visible = core_exposed
		jaw_core_flame.scale = Vector2.ONE * (0.92 + clampf(jaw_open, 0.0, 1.0) * 0.22)
	if eye_fire != null:
		eye_fire.scale = Vector2.ONE * pulse


func _build_guardian_archetype() -> Resource:
	var result := super._build_guardian_archetype()
	result.set("display_name", "青燐六臂骸武者")
	result.set("visual_color", Color.WHITE)
	result.set("visual_scale", Vector2(0.68, 0.68))
	return result
