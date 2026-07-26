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

	var duplicate_ids: RefCounted = meta_script.new()
	duplicate_ids.call("apply_dict", {
		"schema_version": 3,
		"selected_card_instances": [
			{"instance_id": 1007, "card_id": "ember_bolt", "level": 3},
			{"instance_id": 1007, "card_id": "guard", "level": 2},
			{"instance_id": 1009, "card_id": "quickstep", "level": 2},
		],
	})
	var repaired := duplicate_ids.call("to_dict") as Dictionary
	_expect(
		repaired.get("selected_card_instances", []) == [
			{"instance_id": 1007, "card_id": "ember_bolt", "level": 1},
			{"instance_id": 1010, "card_id": "guard", "level": 2},
			{"instance_id": 1009, "card_id": "quickstep", "level": 1},
		],
		"Modern saves must deterministically repair duplicate instance IDs and fixed-card levels."
	)
	var instance_script := load("res://scripts/systems/card_instance.gd") as GDScript
	var allocated_after_repair: Variant = instance_script.new("guard")
	_expect(
		int(allocated_after_repair.get("instance_id")) > 1010,
		"Repaired IDs must advance the monotonic allocator beyond the collection repair."
	)
	var repaired_again: RefCounted = meta_script.new()
	repaired_again.call("apply_dict", repaired)
	_expect(repaired_again.call("to_dict") == repaired, "Duplicate-ID repair must be idempotent.")

	var reconciled: RefCounted = meta_script.new()
	reconciled.call("apply_dict", {
		"schema_version": 3,
		"selected_card_instances": [
			{"instance_id": 11, "card_id": "ember_bolt", "level": 1},
			{"instance_id": 12, "card_id": "guard", "level": 3},
			{"instance_id": 13, "card_id": "guard", "level": 2},
			{"instance_id": 14, "card_id": "quickstep", "level": 1},
		],
	})
	var reordered_ids: Array[String] = ["ember_bolt", "quickstep", "guard", "healing_light", "guard"]
	reconciled.set("selected_deck", reordered_ids)
	var synchronized := reconciled.call("to_dict") as Dictionary
	_expect(
		synchronized.get("selected_card_instances", []) == [
			{"instance_id": 11, "card_id": "ember_bolt", "level": 1},
			{"instance_id": 14, "card_id": "quickstep", "level": 1},
			{"instance_id": 12, "card_id": "guard", "level": 3},
			{"instance_id": 15, "card_id": "healing_light", "level": 1},
			{"instance_id": 13, "card_id": "guard", "level": 2},
		],
		"Deck synchronization must retain matching instances by card ID/order and allocate only added cards."
	)
	var valid_ids: Array[String] = ["ember_bolt", "quickstep", "guard", "healing_light"]
	reconciled.call("normalize_selected_deck", valid_ids)
	_expect(
		(reconciled.call("to_dict") as Dictionary).get("selected_card_instances", []) == synchronized.get("selected_card_instances", []),
		"Normalizing an already valid deck must preserve all retained instance IDs and levels."
	)

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
