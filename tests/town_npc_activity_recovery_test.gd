extends SceneTree

const FEMALE_VILLAGER_SCENE := preload("res://scenes/npc/town/FemaleVillager.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var residents := Node2D.new()
	root.add_child(residents)
	var resident := FEMALE_VILLAGER_SCENE.instantiate() as TownNPCLife
	residents.add_child(resident)
	await process_frame
	resident.set_process(false)
	resident.life_enabled = true
	resident.minimum_idle_seconds = 2.4
	resident.maximum_idle_seconds = 2.4

	resident.request_rest(0.1)
	resident.advance_life(0.11)
	_expect(
		resident.get_life_state() == &"idle",
		"Completing a rest must enter the neutral idle recovery state before another activity is selected."
	)

	resident.request_role_activity(0.1)
	resident.advance_life(0.11)
	_expect(
		resident.get_life_state() == &"idle",
		"Completing a role activity must enter the neutral idle recovery state before another activity is selected."
	)
	_expect(
		float(resident.get("_state_timer")) >= 10.0,
		"A completed role activity needs a long recovery so the resident does not immediately start another loop."
	)

	var safe_ambient_emotes: Array[StringName] = [&"laugh", &"happy"]
	resident.call("_set_state", &"emote")
	var first_emote := resident.npc_visual.get_active_state()
	resident.call("_set_state", &"emote")
	var second_emote := resident.npc_visual.get_active_state()
	_expect(
		safe_ambient_emotes.has(first_emote) and safe_ambient_emotes.has(second_emote),
		"Ambient emotion selection must not invent sadness, anger, or surprise without an event."
	)
	_expect(
		first_emote != second_emote,
		"Ambient emotion selection must not repeat the same visible emotion consecutively."
	)

	resident.social_chance = 0.0
	resident.walk_speed = 10000.0
	resident.minimum_idle_seconds = 0.1
	resident.maximum_idle_seconds = 0.1
	var previous_activity: StringName
	for cycle in range(8):
		resident.call("_choose_next_activity")
		var current_activity := resident.get_life_state()
		_expect(
			current_activity != previous_activity,
			"Local scheduler cycle %d must not repeat %s consecutively." % [cycle, current_activity]
		)
		previous_activity = current_activity
		resident.advance_life(10.0)
		_expect(
			resident.get_life_state() == &"idle",
			"Every completed local scheduler activity must return to neutral idle recovery."
		)

	residents.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC activities use a neutral recovery interval")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
