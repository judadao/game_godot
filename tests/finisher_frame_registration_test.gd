extends SceneTree

const NAMED_SKILL_VFX_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const HORIZONTAL_FINISHERS: Array[String] = [
	"silent_battle_rhythm",
	"thousand_blade_kill",
	"guarding_shared_pulse",
	"gale_reservoir",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := get_root()
	for finisher_id in HORIZONTAL_FINISHERS:
		var effect := NAMED_SKILL_VFX_SCENE.instantiate()
		root.add_child(effect)
		await process_frame
		effect.set("auto_free", false)
		effect.call("play", finisher_id, 1, 1.0, true, 1, 0)
		_validate_row_registration(effect, finisher_id)
		if finisher_id in ["silent_battle_rhythm", "gale_reservoir"]:
			_validate_directional_follow_through(effect, finisher_id)
		_validate_wall_free_playback(effect, finisher_id)
		effect.queue_free()
		await process_frame
	_finish()


func _validate_row_registration(effect: Node, finisher_id: String) -> void:
	var state := effect.call("get_finisher_debug_state") as Dictionary
	_expect(
		bool(state.get("y_registration_enabled", false)),
		"%s must enable row Y registration for its non-vertical authored sequence." % finisher_id
	)
	var row_offsets := state.get("frame_row_registration_offsets", []) as Array
	var registered_baselines := state.get("registered_row_baselines", []) as Array
	_expect(
		row_offsets.size() == 3 and registered_baselines.size() == 3,
		"%s must expose one Y registration offset and normalized baseline per atlas row." % finisher_id
	)
	if row_offsets.size() != 3 or registered_baselines.size() != 3:
		return
	_expect(
		absf(float(row_offsets[1])) > 0.5 or absf(float(row_offsets[2])) > 0.5,
		"%s must correct the authored row shift instead of retaining one shared sheet offset." % finisher_id
	)
	for baseline in registered_baselines:
		_expect(
			is_equal_approx(float(baseline), float(registered_baselines[0])),
			"%s must keep every atlas row on the same registered Y baseline." % finisher_id
		)


func _validate_directional_follow_through(effect: Node, finisher_id: String) -> void:
	effect.call("debug_set_progress", 0.72)
	var contact_state := effect.call("get_finisher_debug_state") as Dictionary
	effect.call("debug_set_progress", 1.0)
	var release_state := effect.call("get_finisher_debug_state") as Dictionary
	var contact_x := (contact_state.get("runtime_target_offset", Vector2.ZERO) as Vector2).x
	var release_x := (release_state.get("runtime_target_offset", Vector2.ZERO) as Vector2).x
	_expect(
		release_x >= contact_x + 24.0,
		"%s must continue through the contact point instead of stopping against an invisible wall." % finisher_id
	)


func _validate_wall_free_playback(effect: Node, finisher_id: String) -> void:
	if finisher_id == "thousand_blade_kill":
		for frame_index in [6, 7, 10]:
			effect.call("debug_set_progress", float(frame_index) / 11.0)
			var feather_state := effect.call("get_finisher_debug_state") as Dictionary
			_expect(
				int(feather_state.get("authored_timeline_frame_index", -1)) == frame_index,
				"thousand_blade_kill must preserve all twelve authored timeline slots."
			)
			_expect(
				int(feather_state.get("authored_frame_index", -1)) not in [6, 7, 10],
				"thousand_blade_kill must turn in open air without a painted boundary hinge."
			)
	if finisher_id == "guarding_shared_pulse":
		effect.call("debug_set_progress", 9.0 / 11.0)
		var shield_state := effect.call("get_finisher_debug_state") as Dictionary
		_expect(
			int(shield_state.get("authored_timeline_frame_index", -1)) == 9,
			"guarding_shared_pulse must preserve all twelve authored timeline slots."
		)
		_expect(
			int(shield_state.get("authored_frame_index", -1)) != 9,
			"guarding_shared_pulse must skip the authored cel containing a separate target wall."
		)
	if finisher_id == "gale_reservoir":
		for frame_index in [10, 11]:
			effect.call("debug_set_progress", float(frame_index) / 11.0)
			var tide_state := effect.call("get_finisher_debug_state") as Dictionary
			_expect(
				int(tide_state.get("authored_timeline_frame_index", -1)) == frame_index,
				"gale_reservoir must preserve all twelve authored timeline slots."
			)
			_expect(
				int(tide_state.get("authored_frame_index", -1)) not in [10, 11],
				"gale_reservoir must not play the authored wall cels at the end of its water route."
			)


func _finish() -> void:
	if _failures == 0:
		print("PASS: finisher rows stay registered and horizontal attacks follow through")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
