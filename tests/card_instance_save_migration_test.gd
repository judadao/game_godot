extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var meta_script := load("res://scripts/systems/meta_state.gd") as GDScript
	var save_script := load("res://scripts/systems/save_service.gd") as GDScript
	_expect(meta_script != null, "MetaState must load for card-instance migration.")
	_expect(save_script != null, "SaveService must load for card-instance migration.")
	if meta_script == null or save_script == null:
		quit(1)
		return

	# Schema 2 predates intrinsic Dash and may contain Quickstep. Keep this one
	# fixture to verify deterministic decoding of historical saves.
	var legacy_payload := {
		"schema_version": 2,
		"selected_deck": ["ember_bolt", "guard", "guard", "quickstep"],
		"permanent_card_levels": {"ember_bolt": 3, "guard": 3, "quickstep": 2},
		"unlocked_combos": ["ember_chain"],
	}
	var meta: MetaState = meta_script.new()
	meta.apply_dict(legacy_payload)
	var migrated := meta.to_dict()
	var instances := migrated.get("selected_card_instances", []) as Array
	_expect(int(migrated.get("schema_version", 0)) == 8, "Skill-series migration saves must use schema version eight.")
	_expect(
		(migrated.get("learned_skill_ids", []) as Array).is_empty()
		and (migrated.get("active_skill_ids", []) as Array).is_empty(),
		"Legacy saves must not recreate retired passive Skill records."
	)
	_expect(
		instances == [
			{"instance_id": "legacy-000001", "card_id": "ember_bolt", "level": 3},
			{"instance_id": "legacy-000002", "card_id": "guard", "level": 3},
			{"instance_id": "legacy-000003", "card_id": "guard", "level": 3},
		],
		"Legacy migration must preserve valid duplicates while retiring the removed Quickstep card."
	)
	_expect(
		not migrated.has("permanent_card_levels"),
		"Shared card levels must remain migration input only, never the new save authority."
	)
	var report := meta.get_last_migration_report()
	_expect(
		int(report.get("migrated_instances", 0)) == 4
		and int(report.get("fixed_levels_repaired", 0)) == 0
		and int(report.get("retired_cards_removed", 0)) == 1,
		"Migration must report the retired Quickstep while preserving ordinary per-instance levels."
	)

	var reapplied: MetaState = meta_script.new()
	reapplied.apply_dict(migrated)
	_expect(reapplied.to_dict() == migrated, "Migrating a modern payload again must be idempotent.")
	_expect(
		int(reapplied.get_last_migration_report().get("migrated_instances", -1)) == 0,
		"An idempotent modern load must report no legacy conversions."
	)

	var repaired: MetaState = meta_script.new()
	repaired.apply_dict({
		"schema_version": 3,
		"selected_card_instances": [
			{"instance_id": "same", "card_id": "ember_bolt", "level": 3},
			{"instance_id": "same", "card_id": "guard", "level": 2},
			{"instance_id": "frost", "card_id": "frost_bind", "level": 2},
		],
	})
	var repaired_payload := repaired.to_dict()
	_expect(
		repaired_payload.get("selected_card_instances", []) == [
			{"instance_id": "same", "card_id": "ember_bolt", "level": 3},
			{"instance_id": "repair-000002", "card_id": "guard", "level": 2},
			{"instance_id": "frost", "card_id": "frost_bind", "level": 2},
		],
		"Duplicate modern IDs must repair deterministically while ordinary levels remain intact."
	)
	var repaired_again: MetaState = meta_script.new()
	repaired_again.apply_dict(repaired_payload)
	_expect(
		repaired_again.to_dict() == repaired_payload,
		"Repaired modern payloads must remain stable on later loads."
	)

	var numeric_id_save: MetaState = meta_script.new()
	numeric_id_save.apply_dict({
		"schema_version": 3,
		"selected_card_instances": [
			{"instance_id": 1, "card_id": "ember_bolt", "level": 1},
			{"instance_id": 2, "card_id": "frost_bind", "level": 1},
			{"instance_id": 3, "card_id": "guard", "level": 1},
		],
		"selected_deck": ["ember_bolt", "frost_bind", "guard"],
	})
	_expect(
		numeric_id_save.to_dict().get("selected_card_instances", []) == [
			{"instance_id": "1", "card_id": "ember_bolt", "level": 1},
			{"instance_id": "2", "card_id": "frost_bind", "level": 1},
			{"instance_id": "3", "card_id": "guard", "level": 1},
		],
		"Schema-three numeric instance IDs must load as stable strings without losing cards."
	)

	var path := "user://saves/card_instance_save_migration_test.json"
	var save: SaveService = save_script.new()
	_expect(save.save_meta(path, migrated), "A migrated payload must save successfully.")
	var loaded := save.load_meta(path)
	_expect(loaded == migrated, "Modern instance payloads must round-trip without losing cards.")
	_expect(
		int(save.get_last_migration_report().get("migrated_instances", -1)) == 0,
		"SaveService must expose the latest migration report."
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
