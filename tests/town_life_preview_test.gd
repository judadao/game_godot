extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/dev/previews/TownLifePreview.tscn")
const ENTRY_CAPTURE_TIME := 12.0
const SOCIAL_CAPTURE_TIMES := [16.0, 17.0, 18.0, 34.0, 35.0, 36.0]
const EXIT_CAPTURE_TIME := 60.0
const VISITOR_NAMES := ["VisitorFarmer", "VisitorMinstrel"]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	await process_frame
	_expect(preview.has_method("prepare_deterministic_capture"), "Town life preview must expose deterministic setup.")
	_expect(preview.has_method("advance_deterministic_capture"), "Town life preview must expose fixed-step advancement.")
	_expect(preview.has_method("get_visitor_capture_snapshot"), "Town life preview must expose visitor review snapshots.")
	if not preview.has_method("prepare_deterministic_capture"):
		preview.queue_free()
		await process_frame
		_finish()
		return

	var simulation: Dictionary = preview.call("prepare_deterministic_capture")
	var visitors := simulation.get("visitors", []) as Array
	_expect(visitors.size() == 2, "Town life preview must deterministically include both passing visitors.")
	_expect(
		(simulation.get("reserved_residents", []) as Array).size() == 2,
		"Each visitor must retain one available resident partner for deterministic social captures."
	)
	var visitor_names: Array[String] = []
	for visitor in visitors:
		visitor_names.append(String(visitor.name))
		_expect(not visitor.is_processing(), "%s process must be disabled during deterministic capture." % visitor.name)
		_expect(visitor.has_method("advance_visitor"), "%s must be stepped through advance_visitor()." % visitor.name)
	_expect(visitor_names == VISITOR_NAMES, "Visitor capture order must be stable by scene path.")

	preview.call("advance_deterministic_capture", simulation, ENTRY_CAPTURE_TIME)
	var entry_snapshot: Array[Dictionary] = preview.call("get_visitor_capture_snapshot", simulation)
	_expect(
		_any_snapshot_matches(entry_snapshot, [&"crossing"]),
		"The 12-second capture must show at least one visitor entering Town."
	)
	_expect(
		_any_visitor_inside_town(entry_snapshot),
		"The entry capture must place a visitor inside the visible Town bounds."
	)

	var social_capture_found := false
	var social_diagnostics: Array[String] = []
	for sample_time in SOCIAL_CAPTURE_TIMES:
		preview.call("advance_deterministic_capture", simulation, sample_time)
		var social_snapshot: Array[Dictionary] = preview.call("get_visitor_capture_snapshot", simulation)
		social_diagnostics.append("t%.0f=%s" % [sample_time, str(social_snapshot)])
		if _any_snapshot_matches(social_snapshot, [&"social_greet", &"social_chat"]):
			social_capture_found = true
			_expect(
				_any_social_snapshot_has_partner(social_snapshot),
				"A social visitor capture must retain the resident partner name."
			)
			break
	_expect(
		social_capture_found,
		"The deterministic 16/17/18/34/35/36-second captures must include a visitor-resident interaction: %s"
		% "; ".join(social_diagnostics)
	)

	preview.call("advance_deterministic_capture", simulation, EXIT_CAPTURE_TIME)
	var exit_snapshot: Array[Dictionary] = preview.call("get_visitor_capture_snapshot", simulation)
	for snapshot in exit_snapshot:
		_expect(
			int(snapshot.get("completed_passes", 0)) >= 1,
			"%s must complete a cross-town pass by the 60-second capture." % snapshot.get("name", "Visitor")
		)
		_expect(
			StringName(snapshot.get("state", "")) == &"offscreen_wait",
			"%s must be outside Town awaiting its next visit at 60 seconds." % snapshot.get("name", "Visitor")
		)

	preview.queue_free()
	await process_frame
	_finish()


func _any_snapshot_matches(snapshots: Array[Dictionary], states: Array[StringName]) -> bool:
	for snapshot in snapshots:
		if states.has(StringName(snapshot.get("state", ""))):
			return true
	return false


func _any_visitor_inside_town(snapshots: Array[Dictionary]) -> bool:
	for snapshot in snapshots:
		var position := snapshot.get("position", Vector2.ZERO) as Vector2
		if position.x >= 0.0 and position.x <= 1942.0:
			return true
	return false


func _any_social_snapshot_has_partner(snapshots: Array[Dictionary]) -> bool:
	for snapshot in snapshots:
		var state := StringName(snapshot.get("state", ""))
		if state in [&"social_greet", &"social_chat"] and not String(snapshot.get("partner", "")).is_empty():
			return true
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Town life preview deterministically captures visitor entry, socializing, and exit")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
