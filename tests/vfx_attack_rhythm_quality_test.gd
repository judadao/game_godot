extends SceneTree

const INSPECTION_SCENES := {
	"fire_burst": "res://scenes/vfx/primitives/fire/fire_burst.tscn",
	"lightning_impact": "res://scenes/vfx/primitives/lightning/lightning_impact.tscn",
	"water_splash": "res://scenes/vfx/primitives/water/water_splash.tscn",
	"poison_splash": "res://scenes/vfx/primitives/poison/poison_splash.tscn",
	"wind_slash": "res://scenes/vfx/primitives/wind/wind_slash.tscn",
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for effect_id in INSPECTION_SCENES:
		var packed := load(String(INSPECTION_SCENES[effect_id])) as PackedScene
		var effect := packed.instantiate() as Node2D if packed != null else null
		_expect(effect != null, "%s must remain an inspectable reusable scene." % effect_id)
		if effect == null:
			continue
		effect.set("auto_play", false)
		root.add_child(effect)
		await process_frame
		_expect(effect.has_method("get_quality_state"), "%s must expose its authored rhythm and shape diagnostics." % effect_id)
		if effect.has_method("get_quality_state"):
			var state := effect.call("get_quality_state") as Dictionary
			var beats := state.get("rhythm_beats", []) as Array
			var offsets := state.get("layer_phase_offsets", []) as Array
			_expect(beats == ["contact_flash", "shape_expansion", "secondary_debris", "residual_fade"], "%s must use a readable four-beat contact rhythm." % effect_id)
			_expect(int(state.get("visual_layer_count", 0)) >= 5, "%s needs at least five independently readable visual layers." % effect_id)
			_expect(_unique_float_count(offsets) >= 3, "%s layers must not all start and end on the same frame." % effect_id)
			_expect(bool(state.get("directional_shape", false)) == (effect_id == "wind_slash"), "%s must report whether its silhouette is directional." % effect_id)
		effect.queue_free()
		await process_frame
	_finish()


func _unique_float_count(values: Array) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[snappedf(float(value), 0.01)] = true
	return unique.size()


func _finish() -> void:
	if _failures == 0:
		print("PASS: reusable combat primitives separate flash, silhouette, debris, and residual timing")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
