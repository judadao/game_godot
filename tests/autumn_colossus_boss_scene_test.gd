extends SceneTree

const BOSS_SCENE_PATH := "res://scenes/monsters/AutumnSixArmColossusBoss.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(BOSS_SCENE_PATH) as PackedScene
	_expect(packed != null, "The Autumn arena must own a dedicated six-arm colossus scene.")
	if packed == null:
		quit(1)
		return

	var boss := packed.instantiate()
	root.add_child(boss)
	await process_frame

	_expect(boss.has_node("Visual/Core/HeadPivot/UpperSkullKabuto"), "The upper skull and kabuto must be an independent part.")
	_expect(boss.has_node("Visual/Core/HeadPivot/JawPivot/LowerJaw"), "The lower jaw must own an independent vertical pivot.")
	_expect(boss.has_node("Visual/Core/Torso"), "The skeletal torso must be independently replaceable.")
	_expect(boss.has_node("Visual/Core/Pelvis"), "The pelvis and skirt armor must be independently replaceable.")
	_expect(boss.has_node("Visual/SpiritFire/EyeFire"), "Eye fire must be independent from the skull art.")
	_expect(boss.has_node("Visual/SpiritFire/JawCoreFlame"), "The exposed jaw-core flame must be independently animated.")

	var armature := boss.get_node_or_null("Visual/Armature")
	_expect(armature != null, "The colossus must expose one six-arm armature.")
	if armature != null:
		var arms := armature.get_children().filter(
			func(child: Node) -> bool: return child.name.begins_with("Arm")
		)
		_expect(arms.size() == 6, "The colossus must expose exactly six independent shoulder pivots.")
		for arm_variant in arms:
			var arm := arm_variant as Node
			_expect(
				arm.has_node("ShoulderJoint")
					and arm.has_node("UpperArm")
					and arm.has_node("ElbowPivot/ElbowJoint")
					and arm.has_node("ElbowPivot/Forearm")
					and arm.has_node("ElbowPivot/WristPivot/WristJoint")
					and arm.has_node("ElbowPivot/WristPivot/HandKatana"),
				"Every arm must expose solid shoulder, elbow, wrist, upper arm, forearm, gripping hand, and katana parts.",
			)

	_expect(boss.get_meta("source_concept", "") == "res://docs/art_concepts/autumn_six_arm_oni_key_concept_v2_redlight_ghostfire.png", "The assembled boss must declare the approved key concept authority.")
	_expect(bool(boss.get_meta("legacy_boss_preserved", false)), "The replacement must explicitly preserve the previous boss as an elite candidate.")

	boss.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
