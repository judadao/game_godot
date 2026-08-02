extends SceneTree

const RESIDENT_SCENE := preload("res://scenes/npc/town/MaleVillager.tscn")

class HomeBlocker extends Node2D:
	var home_position := Vector2.ZERO

	func get_home_position() -> Vector2:
		return home_position


var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_deterministic_current_clearance()
	await _assert_home_clearance()
	await _assert_reserved_clearance()
	await _assert_fully_blocked_pair_is_rejected()
	_finish()


func _assert_deterministic_current_clearance() -> void:
	var setup := await _make_pair(0.0, 500.0, "current")
	var actor := setup[0] as TownNPCLife
	var partner := setup[1] as TownNPCLife
	var blocker := Node2D.new()
	blocker.position = Vector2(250.0, 0.0)
	blocker.add_to_group("NPCs")
	actor.get_parent().add_child(blocker)
	var first := actor.call("_resolve_clear_social_targets", partner, 50.0) as Dictionary
	var second := actor.call("_resolve_clear_social_targets", partner, 50.0) as Dictionary
	_expect(first == second, "Meeting clearance search must return deterministic targets.")
	_expect(
		is_equal_approx(float(first.get("self_target_x", INF)), 24.0)
		and is_equal_approx(float(first.get("partner_target_x", INF)), 124.0),
		"Blocked midpoint must shift the complete pair left without changing its spacing."
	)
	_expect(
		absf(blocker.position.x - float(first.get("partner_target_x", INF))) >= 120.0,
		"Shifted meeting must preserve the authored 120px third-NPC clearance."
	)
	actor.get_parent().queue_free()
	await process_frame


func _assert_home_clearance() -> void:
	var setup := await _make_pair(0.0, 500.0, "home")
	var actor := setup[0] as TownNPCLife
	var partner := setup[1] as TownNPCLife
	var home_blocker := HomeBlocker.new()
	home_blocker.position = Vector2(900.0, 0.0)
	home_blocker.home_position = Vector2(250.0, 0.0)
	home_blocker.add_to_group("NPCs")
	actor.get_parent().add_child(home_blocker)
	var meeting := actor.call("_resolve_clear_social_targets", partner, 50.0) as Dictionary
	_expect(
		is_equal_approx(float(meeting.get("self_target_x", INF)), 24.0)
		and is_equal_approx(float(meeting.get("partner_target_x", INF)), 124.0),
		"Meeting search must avoid a third NPC home even when its current position is clear."
	)
	actor.get_parent().queue_free()
	await process_frame


func _assert_reserved_clearance() -> void:
	var setup := await _make_pair(0.0, 500.0, "reserved")
	var actor := setup[0] as TownNPCLife
	var partner := setup[1] as TownNPCLife
	var reserved_actor := RESIDENT_SCENE.instantiate() as TownNPCLife
	reserved_actor.position = Vector2(900.0, 0.0)
	reserved_actor.set_meta("character_id", "reserved_third")
	actor.get_parent().add_child(reserved_actor)
	await process_frame
	reserved_actor.set_process(false)
	reserved_actor.call("_set_state", &"social_walk")
	reserved_actor.set("_target_position", Vector2(250.0, 0.0))
	var meeting := actor.call("_resolve_clear_social_targets", partner, 50.0) as Dictionary
	_expect(
		is_equal_approx(float(meeting.get("self_target_x", INF)), 24.0)
		and is_equal_approx(float(meeting.get("partner_target_x", INF)), 124.0),
		"Meeting search must independently avoid an existing reserved social target."
	)
	actor.get_parent().queue_free()
	await process_frame


func _assert_fully_blocked_pair_is_rejected() -> void:
	var setup := await _make_pair(0.0, 200.0, "blocked")
	var actor := setup[0] as TownNPCLife
	var partner := setup[1] as TownNPCLife
	var blocker := Node2D.new()
	blocker.position = Vector2(100.0, 0.0)
	blocker.add_to_group("NPCs")
	actor.get_parent().add_child(blocker)
	_expect(
		(actor.call("_resolve_clear_social_targets", partner, 50.0) as Dictionary).is_empty(),
		"A fully occupied interval must not fall back to an overlapping midpoint."
	)
	_expect(
		not bool(actor.call("_try_begin_social_pair")),
		"A pair without a safe meeting point must cancel its invitation."
	)
	_expect(
		actor.get_social_partner() == null
		and partner.get_social_partner() == null
		and actor.get_life_state() == &"idle"
		and partner.get_life_state() == &"idle"
		and actor.get_active_interaction_id().is_empty()
		and partner.get_active_interaction_id().is_empty()
		and (actor.get("_interaction_sequence") as Array).is_empty()
		and (partner.get("_interaction_sequence") as Array).is_empty(),
		"Rejected meeting must not leave a half-reserved partner or interaction."
	)
	actor.get_parent().queue_free()
	await process_frame


func _make_pair(left_x: float, right_x: float, prefix: String) -> Array[TownNPCLife]:
	var group := Node2D.new()
	root.add_child(group)
	var actor := RESIDENT_SCENE.instantiate() as TownNPCLife
	var partner := RESIDENT_SCENE.instantiate() as TownNPCLife
	actor.position = Vector2(left_x, 0.0)
	partner.position = Vector2(right_x, 0.0)
	actor.set_meta("character_id", "%s_actor" % prefix)
	partner.set_meta("character_id", "%s_partner" % prefix)
	group.add_child(actor)
	group.add_child(partner)
	await process_frame
	actor.set_process(false)
	partner.set_process(false)
	actor.social_radius = absf(right_x - left_x) + 100.0
	partner.social_radius = actor.social_radius
	return [actor, partner]


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC social meetings preserve third-character clearance")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
