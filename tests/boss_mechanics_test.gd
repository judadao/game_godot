extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var guardian := (load("res://scenes/monsters/AutumnGuardian.tscn") as PackedScene).instantiate()
	root.add_child(guardian)
	await process_frame
	_expect(guardian.has_method("get_pattern_profile"), "Boss must expose distinct attack mechanics.")
	if not guardian.has_method("get_pattern_profile"):
		guardian.queue_free()
		await process_frame
		quit(1)
		return
	var sweep := guardian.call("get_pattern_profile", &"root_sweep") as Dictionary
	var acorns := guardian.call("get_pattern_profile", &"falling_acorns") as Dictionary
	var burst := guardian.call("get_pattern_profile", &"ember_burst") as Dictionary
	_expect(sweep.get("kind") == "melee_arc", "Phase one must test close-range movement.")
	_expect(acorns.get("kind") == "falling_hazard", "Phase two must add a field hazard.")
	_expect(burst.get("kind") == "radial_burst", "Phase three must add a radial burst.")
	_expect(
		float(acorns.get("range", 0.0)) > float(sweep.get("range", 0.0))
		and int(burst.get("damage", 0)) > int(acorns.get("damage", 0)),
		"Boss phases must escalate range and damage, not only rename attacks."
	)
	guardian.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
