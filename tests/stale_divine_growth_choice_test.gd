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
	game.set_process(false)
	var gifts := game.get("divine_gift_manager") as RefCounted
	gifts.call("reset_run")
	for gift_id in ["prismatic_oath", "radiant_mercy"]:
		for _level in 3:
			_expect(bool(gifts.call("add_or_upgrade", gift_id)), "%s must reach Lv.3." % gift_id)
	for _level in 2:
		_expect(bool(gifts.call("add_or_upgrade", "celestial_momentum")), "Wind Blessing must reach Lv.2.")

	game.call("_show_combat_blessing_choices", "elite")
	game.call("_show_combat_blessing_choices", "elite")
	await process_frame
	await process_frame
	var first_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(first_ui != null and paused, "The first elite reward must open as a paused modal.")
	var first_page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var first_choices := first_page.get("choices", []) as Array
	_expect(
		first_choices.size() == 1
			and String((first_choices[0] as Dictionary).get("gift_id", "")) == "celestial_momentum",
		"The first queued reward must offer the only Lv.2 Blessing upgrade."
	)
	var first_confirm := first_ui.find_child("ConfirmButton", true, false) as Button
	first_confirm.pressed.emit()
	await process_frame
	await process_frame

	var second_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(second_ui != null and second_ui != first_ui, "Confirm click must close the resolved modal and open the next page.")
	var refreshed_page := (game.get("growth_choice_queue") as GrowthChoiceQueue).peek()
	var refreshed_choices := refreshed_page.get("choices", []) as Array
	var fallback_only := refreshed_choices.size() == 3
	for choice_variant in refreshed_choices:
		fallback_only = fallback_only and String((choice_variant as Dictionary).get("action", "")) == "fallback"
	_expect(
		fallback_only,
		"A queued elite page made stale by the previous selection must refresh to valid fallback rewards instead of trapping the modal."
	)
	var second_confirm := second_ui.find_child("ConfirmButton", true, false) as Button
	second_confirm.pressed.emit()
	await process_frame
	await process_frame
	_expect(
		(game.get("growth_choice_queue") as GrowthChoiceQueue).is_empty()
			and game.get_open_ui("CardGrowthUI") == null
			and not paused,
		"Clicking the refreshed fallback must resolve the queue and resume combat."
	)

	game.queue_free()
	await process_frame
	paused = false
	if _failures == 0:
		print("PASS: stale queued Blessing choices refresh and remain clickable")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
