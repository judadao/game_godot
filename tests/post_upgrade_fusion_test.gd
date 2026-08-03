extends SceneTree

class SuccessfulSaveService:
	extends SaveService

	func save_meta(_path: String, _data: Dictionary) -> bool:
		return true


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("save_service", SuccessfulSaveService.new())
	game.call("_begin_autumn_run")
	var gifts := game.get("divine_gift_manager") as RefCounted
	for gift_id in ["resonant_grace", "boundless_font"]:
		for _level in 3:
			_expect(bool(gifts.call("add_or_upgrade", gift_id)), "Fusion materials must reach Lv.3.")
	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame

	var fusion_queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	var fusion_page := fusion_queue.peek()
	var fusion_choices := fusion_page.get("choices", []) as Array
	var fusion_choice: Dictionary = {}
	for choice_variant in fusion_choices:
		if String((choice_variant as Dictionary).get("action", "")) == "divine_fusion":
			fusion_choice = (choice_variant as Dictionary).duplicate(true)
			break
	var growth_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(
		growth_ui != null
			and String(fusion_page.get("source", "")) == "elite"
			and not fusion_choice.is_empty(),
		"Only elite or boss loot may offer a Blessing merge."
	)
	growth_ui.call("select_choice", String(fusion_choice.get("choice_id", "")))
	growth_ui.call("confirm_selected_choice")
	await process_frame
	var inventory := gifts.call("get_inventory") as Array
	_expect(
		inventory.size() == 1
			and String((inventory[0] as Dictionary).get("kind", "")) == "evolved",
		"Choosing elite loot merge must consume two Lv.3 Blessings and create one evolved Blessing."
	)
	_expect(fusion_queue.is_empty() and not paused, "Finishing elite fusion must resume combat.")

	game.queue_free()
	await process_frame
	paused = false
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
