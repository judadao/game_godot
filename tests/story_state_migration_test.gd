extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy := MetaState.new()
	legacy.apply_dict({"schema_version": 8, "resources": {"gold": 12}})
	var migrated := legacy.to_dict()
	_expect(int(migrated.get("schema_version", 0)) >= 11, "Expedition fragment progress requires save schema version eleven or later.")
	var story := migrated.get("story_state", {}) as Dictionary
	_expect(String(story.get("chapter_id", "")) == "chapter_01", "Legacy saves start at chapter one.")
	_expect((story.get("story_flags", []) as Array).is_empty(), "Legacy saves do not invent completed story flags.")

	var schema_ten := MetaState.new()
	schema_ten.apply_dict({
		"schema_version": 10,
		"region_clear_counts": {"autumn": 4, "crystal": 2},
		"region_boss_defeated": {"autumn": false},
	})
	_expect(
		schema_ten.get_region_boss_fragment_count(&"autumn") == 4
			and schema_ten.has_region_boss_key(&"autumn")
			and schema_ten.get_region_boss_fragment_count(&"crystal") == 2,
		"Schema 10 clear counts must migrate into equivalent fragments and assembled keys."
	)

	var restored := MetaState.new()
	restored.apply_dict({
		"schema_version": 9,
		"story_state": {
			"chapter_id": "chapter_01",
			"next_sequence_id": "chapter_01_forge",
			"story_flags": ["protagonist_town_routine_established"],
		},
	})
	var round_trip := restored.to_dict().get("story_state", {}) as Dictionary
	_expect(String(round_trip.get("next_sequence_id", "")) == "chapter_01_forge", "Story checkpoint round-trips.")
	_expect(
		(round_trip.get("story_flags", []) as Array) == ["protagonist_town_routine_established"],
		"Story flags round-trip without duplication or loss."
	)

	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
