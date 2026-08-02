extends SceneTree

const WITCH_SCENE := preload("res://scenes/npc/town/FemaleVillager.tscn")
const AUTHORED_EMOTION_STATES: Array[StringName] = [
	&"laugh", &"happy", &"sad", &"surprised", &"angry",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var witch := WITCH_SCENE.instantiate() as TownNPCLife
	root.add_child(witch)
	await process_frame
	witch.set_process(false)
	var visual := witch.npc_visual
	visual.set_process(false)
	var exposes_overlay_contract := visual.has_method("has_runtime_overlay_for_active_state")
	_expect(
		exposes_overlay_contract,
		"TownNPCVisual must expose which active states add a runtime overlay."
	)
	if exposes_overlay_contract:
		for state in AUTHORED_EMOTION_STATES:
			visual.play_state(state)
			_expect(
				not bool(visual.call("has_runtime_overlay_for_active_state")),
				"%s must rely on its authored atlas symbols without a duplicate overlay." % state
			)
		visual.play_state(&"chat")
		_expect(
			bool(visual.call("has_runtime_overlay_for_active_state")),
			"Chat must retain its runtime conversation marks."
		)
	witch.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: authored Town emotions do not receive duplicate runtime marks")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
