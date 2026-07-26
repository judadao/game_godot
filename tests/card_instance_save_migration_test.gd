extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var meta_script := load("res://scripts/systems/meta_state.gd") as GDScript
	var save_script := load("res://scripts/systems/save_service.gd") as GDScript
	_expect(meta_script != null, "MetaState must load for instance-save migration coverage.")
	_expect(save_script != null, "SaveService must load for instance-save migration coverage.")
	if meta_script == null or save_script == null:
		quit(1)
		return

	var legacy_payload := {
		"schema_version": 2,
		"selected_deck": ["ember_bolt", "guard", "guard", "quickstep"],
		"permanent_card_levels": {"ember_bolt": 3, "guard": 3, "quickstep": 2},
		"unlocked_combos": ["ember_chain"],
	}
	var migrated: RefCounted = meta_script.new()
	migrated.call("apply_dict", legacy_payload)
	var first := migrated.call("to_dict") as Dictionary
	_expect(int(first.get("schema_version", 0)) > 2, "Instance-aware saves must bump the schema version.")
	var instances := first.get("selected_card_instances", []) as Array
	_expect(instances.size() == 4, "Legacy selected_deck entries must migrate into one instance each.")
	_expect(
		instances == [
			{"instance_id": 1, "card_id": "ember_bolt", "level": 1},
			{"instance_id": 2, "card_id": "guard", "level": 3},
			{"instance_id": 3, "card_id": "guard", "level": 3},
			{"instance_id": 4, "card_id": "quickstep", "level": 1},
		],
		"Legacy shared levels must migrate deterministically while fixed cards remain level one."
	)
	_expect(first.has("learned_skills") and first.has("skill_loadout"), "Instance saves must serialize learned skills and their loadout.")
	_expect(not first.has("permanent_card_levels"), "Shared permanent card levels must be migration-only, not an active saved authority.")

	var remigrated: RefCounted = meta_script.new()
	remigrated.call("apply_dict", first)
	_expect(remigrated.call("to_dict") == first, "Applying an already migrated payload must be idempotent.")

	var path := "user://saves/card_instance_save_migration_test.json"
	var save: RefCounted = save_script.new()
	_expect(bool(save.call("save_meta", path, first)), "Migrated instance saves must persist successfully.")
	var loaded := save.call("load_meta", path) as Dictionary
	_expect(loaded == first, "SaveService must load an instance save without changing it.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
