extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var builder := (
		load("res://scenes/ui/DeckBuilderUI.tscn") as PackedScene
	).instantiate()
	root.add_child(builder)
	await process_frame
	builder.call("configure", database.get_all_cards(), [
		"healing_light", "flame_imbue", "echo_volley", "storm_charge",
	])

	_expect(
		builder.has_node("Shade/LoadoutPanel/Margin/Column/LoadoutSlots"),
		"Portal loadout must present four explicit skill slots."
	)
	_expect(
		builder.has_node("Shade/LoadoutPanel/Margin/Column/RecipeSummary"),
		"Portal loadout must explain which named Finishers the four slots enable."
	)
	var slots := builder.call("get_slot_card_ids") as Array
	_expect(
		slots == [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		],
		"Four slots must preserve one Healing slot followed by three Combo slots."
	)

	builder.call("select_slot", 0)
	var healing_choices := builder.call("get_visible_choice_ids") as Array
	_expect(
		not healing_choices.is_empty()
			and _all_cards_have_type(database, healing_choices, "healing"),
		"Selecting the Healing slot must show Healing cards only."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "renewal")),
		"A Healing choice must replace only the Healing slot."
	)

	builder.call("select_slot", 1)
	var combo_choices := builder.call("get_visible_choice_ids") as Array
	_expect(
		not combo_choices.is_empty()
			and _all_cards_have_type(database, combo_choices, "combo"),
		"Selecting a Combo slot must show Combo cards only."
	)
	_expect(
		not bool(builder.call("choose_card_for_active_slot", "renewal")),
		"A Combo slot must reject Healing cards."
	)
	_expect(
		not bool(builder.call("choose_card_for_active_slot", "echo_volley")),
		"The three Combo slots must reject duplicate skills."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "frostburst_imbue")),
		"An available Combo choice must replace only the active Combo slot."
	)

	var selected := builder.call("get_selected_deck") as Array
	_expect(
		selected == [
			"renewal", "frostburst_imbue", "echo_volley", "storm_charge",
		],
		"Confirmation order must match the visible Healing, Combo 1, Combo 2, Combo 3 slots."
	)
	var recipe_summary := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/RecipeSummary"
	) as Label
	_expect(
		recipe_summary.text.contains("霜葬")
			and recipe_summary.text.contains("千刃殺")
			and recipe_summary.text.contains("雷獄穿心"),
		"Finisher summary must immediately reflect the selected Combo skills."
	)

	builder.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: explicit Healing and three Combo loadout slots")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _all_cards_have_type(
	database: CardDatabase,
	card_ids: Array,
	expected_type: String
) -> bool:
	for card_id in card_ids:
		if String(database.get_card(String(card_id)).get("type", "")) != expected_type:
			return false
	return true
