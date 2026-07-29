extends SceneTree

const PROFILE_IDS := [
	"thousand_blade_kill",
	"inferno_cremation",
	"thunder_prison_pierce",
	"heavenly_wheel_sever",
	"frozen_burial",
	"iron_momentum",
	"ember_reprise",
	"battle_tempo",
	"grand_strategy",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var vfx_scene := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	_expect(vfx_scene != null, "Named skill evolution needs the reusable VFX scene.")
	if vfx_scene == null:
		_finish()
		return

	var effect := vfx_scene.instantiate()
	root.add_child(effect)
	await process_frame
	_expect(
		_method_argument_count(effect, &"play") >= 6,
		"Named skill VFX play must accept evolution level and persistent buff stacks."
	)
	_expect(
		effect.has_method("get_evolution_level")
			and effect.has_method("get_buff_stack_tier")
			and effect.has_method("get_active_layer_count")
			and effect.has_method("get_animation_archetype"),
		"Named skill VFX must expose evolution, stack, layer, and archetype diagnostics."
	)
	if _method_argument_count(effect, &"play") >= 6:
		effect.call("play", "thousand_blade_kill", 1, 1.0, true, 3, 7)
		_expect(
			int(effect.call("get_evolution_level")) == 3,
			"Level-three skills must retain their evolved visual tier."
		)
		_expect(
			int(effect.call("get_buff_stack_tier")) >= 2,
			"Seven persistent stacks must unlock multiple readable VFX layers."
		)
		_expect(
			int(effect.call("get_active_layer_count")) >= 9,
			"Evolved stacked skills must assemble extra parts instead of only scaling brighter."
		)

	var archetypes: Dictionary = {}
	for profile_id in PROFILE_IDS:
		var candidate := vfx_scene.instantiate()
		root.add_child(candidate)
		await process_frame
		if _method_argument_count(candidate, &"play") >= 6:
			candidate.call("play", profile_id, 1, 1.0, true, 2, 3)
			var archetype := String(candidate.call("get_animation_archetype"))
			_expect(not archetype.is_empty(), "%s must declare an animation archetype." % profile_id)
			_expect(
				not archetypes.has(archetype),
				"%s must not reuse the '%s' motion template." % [profile_id, archetype]
			)
			archetypes[archetype] = profile_id
		candidate.queue_free()
	_expect(
		archetypes.size() == PROFILE_IDS.size(),
		"All nine named skills need unique animation topology."
	)

	effect.set("auto_free", false)
	effect.call("play", "grand_strategy", 1, 1.0, true, 3, 6)
	_expect(
		int(effect.call("get_active_layer_count")) > 5,
		"Evolved replay setup must assemble accent layers."
	)
	effect.call("play", "iron_momentum", 1, 1.0, true, 1, 0)
	await process_frame
	_expect(
		int(effect.call("get_active_layer_count")) == 5
			and effect.get_child_count() == 5,
		"Cross-profile replay must clear prior evolution accents instead of accumulating children."
	)

	effect.queue_free()
	await process_frame
	_finish()


func _method_argument_count(target: Object, method_name: StringName) -> int:
	for method_variant in target.get_method_list():
		var method := method_variant as Dictionary
		if StringName(method.get("name", "")) == method_name:
			return (method.get("args", []) as Array).size()
	return 0


func _finish() -> void:
	if _failures == 0:
		print("PASS: named skill VFX evolves structure and stack readability")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
