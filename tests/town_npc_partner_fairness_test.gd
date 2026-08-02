extends SceneTree

const RESIDENT_SCENE := preload("res://scenes/npc/town/FemaleVillager.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cooldown_group := await _make_resident_group("cooldown")
	var cooldown_actor := cooldown_group[0] as TownNPCLife
	var recent_neighbor := cooldown_group[1] as TownNPCLife
	var fresh_neighbor := cooldown_group[2] as TownNPCLife
	cooldown_actor.call("_mark_partner_cooldown", recent_neighbor, 30.0)
	recent_neighbor.call("_mark_partner_cooldown", cooldown_actor, 30.0)
	_expect(bool(cooldown_actor.call("_try_begin_social_pair")), "A fresh neighbor must remain available for social interaction.")
	_expect(
		cooldown_actor.get_social_partner() == fresh_neighbor,
		"A resident must not immediately choose a recently used social partner when another neighbor is free."
	)
	_expect(recent_neighbor.get_social_partner() == null, "Recent-partner cooldown must leave that neighbor unreserved.")
	(cooldown_actor.get_parent() as Node).queue_free()
	await process_frame

	var fairness_group := await _make_resident_group("fairness")
	var fairness_actor := fairness_group[0] as TownNPCLife
	var familiar_neighbor := fairness_group[1] as TownNPCLife
	var less_familiar_neighbor := fairness_group[2] as TownNPCLife
	fairness_actor.call("_increment_relationship", familiar_neighbor)
	familiar_neighbor.call("_increment_relationship", fairness_actor)
	_expect(bool(fairness_actor.call("_try_begin_social_pair")), "An eligible less-familiar neighbor must be selectable.")
	_expect(
		fairness_actor.get_social_partner() == less_familiar_neighbor,
		"Equal-distance scheduling must favor the neighbor with fewer prior interactions."
	)
	(fairness_actor.get_parent() as Node).queue_free()
	await process_frame
	_finish()


func _make_resident_group(prefix: String) -> Array[TownNPCLife]:
	var group := Node2D.new()
	root.add_child(group)
	var residents: Array[TownNPCLife] = []
	for index in range(3):
		var resident := RESIDENT_SCENE.instantiate() as TownNPCLife
		resident.position = Vector2(float(index) * 80.0, 0.0)
		resident.set_meta("character_id", "%s_%d" % [prefix, index])
		group.add_child(resident)
		residents.append(resident)
	await process_frame
	for resident in residents:
		resident.set_process(false)
		resident.social_radius = 240.0
	return residents


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC partner cooldown and fair social selection")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
