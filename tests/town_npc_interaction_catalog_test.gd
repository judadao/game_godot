extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/npc/town_npc_interaction_catalog.gd")
const EXPECTED_IDS := [
	"chat",
	"comfort",
	"discuss_work",
	"farewell",
	"gossip",
	"greet",
	"laugh",
	"share_goods",
	"watch_sky",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog: RefCounted = CATALOG_SCRIPT.new()
	_expect(catalog.load_catalog(), "Town NPC interaction catalog must load.")
	_expect(catalog.get_schema_version() == 1, "Catalog must expose schema version 1.")
	var interactions: Array[Dictionary] = catalog.get_all_interactions()
	var interaction_ids: Array[String] = []
	for interaction in interactions:
		interaction_ids.append(String(interaction.get("id", "")))
	_expect(interaction_ids == EXPECTED_IDS, "Interactions must use deterministic ID ordering.")

	var greet_candidates: Array[Dictionary] = catalog.get_candidates(
		&"traveler", &"social", &"witch", &"merchant"
	)
	_expect(_contains_id(greet_candidates, "greet"), "Residents must be able to greet each other.")
	_expect(_contains_id(greet_candidates, "chat"), "Residents must be able to hold a casual chat.")
	for candidate in greet_candidates:
		_expect(candidate.has("actor_a_sequence"), "Resolved candidates must expose actor A animation states.")
		_expect(candidate.has("actor_b_sequence"), "Resolved candidates must expose actor B animation states.")
	var selected_a: Dictionary = catalog.select_candidate(
		&"traveler", &"social", &"witch", &"merchant", 0.42
	)
	var selected_b: Dictionary = catalog.select_candidate(
		&"traveler", &"social", &"witch", &"merchant", 0.42
	)
	_expect(selected_a == selected_b, "Weighted selection must be deterministic for an external roll.")
	var scenic: Dictionary = catalog.select_candidate(
		&"traveler", &"social", &"witch", &"merchant", 0.42, PackedStringArray(["scenic"])
	)
	_expect(String(scenic.get("id", "")) == "watch_sky", "Required tags must constrain deterministic selection.")
	var knowledge_allowlist := PackedStringArray(["discuss_work", "chat", "watch_sky"])
	var knowledge_results: Array[String] = []
	for roll in [0.0, 0.75, 0.99]:
		var selected := _select_with_allowlist(
			catalog, roll, PackedStringArray(), knowledge_allowlist
		)
		var selected_id := String(selected.get("id", ""))
		knowledge_results.append(selected_id)
		_expect(
			knowledge_allowlist.has(selected_id),
			"Witch-scientist profile selection must stay inside its interaction allowlist."
		)
	_expect(
		knowledge_results == ["chat", "discuss_work", "watch_sky"],
		"Allowlist filtering must preserve existing priority and weighted selection order."
	)
	var allowed_scenic := _select_with_allowlist(
		catalog, 0.42, PackedStringArray(["scenic"]), knowledge_allowlist
	)
	_expect(
		String(allowed_scenic.get("id", "")) == "watch_sky",
		"Required tags must apply after allowlist filtering."
	)
	var empty_allowlist_result := _select_with_allowlist(
		catalog,
		0.42,
		PackedStringArray(),
		PackedStringArray(["farewell_only_if_it_existed"])
	)
	_expect(empty_allowlist_result.is_empty(), "An allowlist with no eligible ID must return no selection.")

	_expect(
		catalog.is_pair_eligible(&"share_goods", &"grocer", &"merchant", &"traveler", &"visitor"),
		"A merchant must be able to share goods with a visitor."
	)
	_expect(
		not catalog.is_pair_eligible(&"share_goods", &"traveler", &"visitor", &"grocer", &"merchant"),
		"Directional share-goods roles must not silently swap."
	)
	_expect(
		catalog.is_pair_eligible(&"watch_sky", &"visitor_one", &"visitor", &"priest", &"spiritual"),
		"Visitor and resident archetypes must query the same catalog."
	)
	_expect(
		not catalog.is_pair_eligible(&"gossip", &"visitor_one", &"visitor", &"visitor_two", &"visitor"),
		"Resident-only gossip must not be offered to two passing visitors."
	)

	var greet: Dictionary = catalog.get_interaction(&"greet")
	(greet.get("tags", []) as Array).append("consumer_mutation")
	_expect(
		not (catalog.get_interaction(&"greet").get("tags", []) as Array).has("consumer_mutation"),
		"Catalog getters must return deep copies."
	)

	var invalid := {
		"schema_version": 1,
		"interactions": [{
			"id": "bad interaction",
			"tags": ["social"],
			"participants": [{
				"roles": ["*"],
				"archetypes": ["*"],
				"animation_sequence": [{"state": "teleport", "seconds": -1.0}],
			}, {
				"roles": ["*"],
				"archetypes": ["*"],
				"animation_sequence": [{"state": "idle", "seconds": 1.0}],
			}],
			"duration_seconds": 1.0,
			"social_distance": {"minimum": 140.0, "preferred": 80.0, "maximum": 60.0},
			"cooldown_seconds": 0.1,
			"weight": 1.0,
			"priority": 10,
			"visitor_allowed": true,
			"bidirectional": true,
			"movement_speed": 10.0,
		}],
	}
	var errors: PackedStringArray = catalog.validate_catalog_data(invalid)
	_expect(errors.size() >= 6, "Schema validation must reject IDs, animation, timing, distance, cooldown, and authority fields.")
	_expect(_errors_mention(errors, "movement_speed"), "Catalog schema must reject movement authority fields.")

	_finish()


func _contains_id(items: Array[Dictionary], target_id: String) -> bool:
	for item in items:
		if String(item.get("id", "")) == target_id:
			return true
	return false


func _select_with_allowlist(
	catalog: RefCounted,
	roll: float,
	required_tags: PackedStringArray,
	allowed_interaction_ids: PackedStringArray
) -> Dictionary:
	return catalog.select_candidate(
		&"witch",
		&"merchant",
		&"scientist",
		&"scholar",
		roll,
		required_tags,
		allowed_interaction_ids
	)


func _errors_mention(errors: PackedStringArray, needle: String) -> bool:
	for error in errors:
		if error.contains(needle):
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town NPC interaction catalog schema and pair resolution")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
