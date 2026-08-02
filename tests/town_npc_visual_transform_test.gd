extends SceneTree

const SAMPLE_SCENE := preload("res://scenes/npc/town/MaleVillager.tscn")
const AUTHORED_STATES: Array[StringName] = [
	&"idle", &"laugh", &"happy", &"sad", &"surprised", &"angry",
	&"idle_look", &"idle_stretch", &"greet", &"work",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor := SAMPLE_SCENE.instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_process(false)
	var visual := actor.get_node("Visual") as TownNPCVisual
	visual.set_process(false)
	visual.ambient_enabled = false

	for state in AUTHORED_STATES:
		visual.play_state(state)
		var reference := visual.get_animation_snapshot() as Dictionary
		var reference_scale := reference.get("scale", Vector2.ZERO) as Vector2
		for _frame in range(4):
			visual.advance_animation(0.21)
			var snapshot := visual.get_animation_snapshot() as Dictionary
			_expect(
				(snapshot.get("scale", Vector2.ZERO) as Vector2).is_equal_approx(reference_scale),
				"%s must not simulate authored motion through whole-body scaling." % state
			)
			_expect(
				(snapshot.get("position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.ZERO),
				"%s must keep the authored foot baseline instead of bobbing the whole body." % state
			)

	actor.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: Town NPC authored states preserve scale and foot baseline")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
