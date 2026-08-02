extends SceneTree

const WITCH_SCENE := preload("res://scenes/npc/town/FemaleVillager.tscn")
const SCIENTIST_SCENE := preload("res://scenes/npc/town/Blacksmith.tscn")
const REQUIRED_ACTIONS := {
	"witch": [&"read_grimoire", &"brew_potion", &"divination", &"cast_ward", &"hidden_concern"],
	"scientist": [&"write_notes", &"measure", &"assemble", &"malfunction", &"inspiration", &"concern"],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var group := Node2D.new()
	root.add_child(group)
	var actors := [
		WITCH_SCENE.instantiate() as TownNPCLife,
		SCIENTIST_SCENE.instantiate() as TownNPCLife,
	]
	for actor in actors:
		group.add_child(actor)
	await process_frame
	for actor in actors:
		actor.set_process(false)
		var character_id := String(actor.get_meta("character_id", ""))
		var supported: Array[StringName] = actor.npc_visual.get_supported_states()
		for action in REQUIRED_ACTIONS[character_id]:
			_expect(supported.has(action), "%s must support authored action %s." % [character_id, action])
			_expect(actor.npc_visual.play_state(action), "%s action %s must be playable." % [character_id, action])
			var first: Dictionary = actor.npc_visual.get_animation_snapshot()
			actor.npc_visual.advance_animation(0.6)
			var second: Dictionary = actor.npc_visual.get_animation_snapshot()
			_expect(first != second, "%s action %s must animate through authored frames." % [character_id, action])
			actor.npc_visual.advance_animation(2.4)
			var held: Dictionary = actor.npc_visual.get_animation_snapshot()
			_expect(
				int(held.get("frame", -1)) == 3,
				"%s action %s must play once and briefly hold its final pose."
				% [character_id, action]
			)
			actor.npc_visual.advance_animation(2.0)
			var settled: Dictionary = actor.npc_visual.get_animation_snapshot()
			_expect(
				settled.get("state", &"") == action,
				"%s action %s must retain its logical role state during the calm dwell."
				% [character_id, action]
			)
			_expect(
				settled.get("rendered_state", &"") == &"idle",
				"%s action %s must settle into slow idle instead of looping or freezing."
				% [character_id, action]
			)
			actor.npc_visual.advance_animation(1.1)
			var breathing: Dictionary = actor.npc_visual.get_animation_snapshot()
			_expect(
				int(breathing.get("frame", -1)) != int(settled.get("frame", -1)),
				"%s action %s settled idle must keep a gentle 1 FPS breathing cadence."
				% [character_id, action]
			)
		_expect(actor.has_method("request_character_activity"), "%s must expose character activity requests." % character_id)
		if actor.has_method("request_character_activity"):
			actor.call("request_character_activity", REQUIRED_ACTIONS[character_id][0], 0.2)
			_expect(actor.get_life_state() == &"role_activity", "%s must expose a requested character activity." % character_id)
			_expect(actor.npc_visual.get_active_state() == REQUIRED_ACTIONS[character_id][0], "%s must render its requested character activity." % character_id)
	group.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC character-specific action animations")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
