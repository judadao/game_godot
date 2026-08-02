extends SceneTree

const NON_FINISHER_SKILL_IDS := [
	"fortress_stance",
	"energy_surge",
	"kinetic_acceleration",
	"crushing_momentum",
	"keen_focus_combo",
	"ascendant_combo",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "Card catalog must load.")
	var builder := (
		load("res://scenes/ui/cards/DeckBuilderUI.tscn") as PackedScene
	).instantiate()
	root.add_child(builder)
	await process_frame
	var localized_cards := _with_chinese_display_names(database.get_all_cards(), {
		"healing_light": "治癒之光",
		"renewal": "復甦之靈",
		"verdant_renewal": "翠綠復甦",
		"storm_charge": "風暴充能",
	})
	builder.call("configure", localized_cards, [
		"healing_light", "renewal", "verdant_renewal", "storm_charge",
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
			"healing_light", "renewal", "verdant_renewal", "storm_charge",
		],
		"Four slots must preserve a valid loadout with multiple Healing skills."
	)

	builder.call("select_slot", 1)
	var mixed_choices := builder.call("get_visible_choice_ids") as Array
	_expect(
		_has_card_type(database, mixed_choices, "healing")
			and _has_card_type(database, mixed_choices, "combo"),
		"A slot must offer both Healing and Combo skills while another Healing remains."
	)
	_expect(
		_not_any_present(mixed_choices, NON_FINISHER_SKILL_IDS),
		"Four-slot choices must exclude skills that cannot advance a Finisher recipe."
	)
	_expect(
		not bool(builder.call("choose_card_for_active_slot", "energy_surge")),
		"A non-Finisher skill must not be accepted into a combat loadout slot."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "echo_volley")),
		"Any slot must accept a Combo while the loadout keeps at least one Healing skill."
	)

	builder.call("select_slot", 0)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "flame_imbue")),
		"The former dedicated Healing slot must also accept a Combo when another Healing remains."
	)
	builder.call("select_slot", 2)
	var last_healing_choices := builder.call("get_visible_choice_ids") as Array
	_expect(
		not last_healing_choices.is_empty()
			and _all_cards_have_type(database, last_healing_choices, "healing"),
		"The final Healing skill must be protected until another Healing skill is equipped."
	)
	_expect(
		not last_healing_choices.has("frostburst_imbue")
			and not bool(builder.call("choose_card_for_active_slot", "frostburst_imbue")),
		"The final Healing slot must reject a Combo replacement."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "renewal")),
		"The final Healing slot may still switch to another Healing skill."
	)

	var selected := builder.call("get_selected_deck") as Array
	_expect(
		selected == [
			"flame_imbue", "echo_volley", "renewal", "storm_charge",
		],
		"Confirmation order must match the four visible mixed skill slots."
	)

	builder.call("configure", localized_cards, [
		"healing_light", "renewal", "verdant_renewal", "storm_charge",
	])
	var recipe_summary := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/RecipeSummary"
	) as Label
	_expect(
		recipe_summary.text.contains("朝光載陽")
			and recipe_summary.text.contains("春庭載陽")
			and recipe_summary.text.contains("治癒之光 → 復甦之靈 → 翠綠復甦"),
		"Finisher summary must include Healing recipes and prefer Chinese display fields."
	)

	builder.call("configure", localized_cards, [
		"energy_surge", "kinetic_acceleration", "healing_light", "storm_charge",
	])
	_expect(
		_not_any_present(builder.call("get_slot_card_ids") as Array, NON_FINISHER_SKILL_IDS),
		"Restoring a legacy loadout must discard skills outside the Finisher catalog."
	)

	builder.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: four mixed Healing/Combo loadout slots with recipe guidance")
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


func _has_card_type(
	database: CardDatabase,
	card_ids: Array,
	expected_type: String
) -> bool:
	for card_id in card_ids:
		if String(database.get_card(String(card_id)).get("type", "")) == expected_type:
			return true
	return false


func _not_any_present(card_ids: Array, excluded_ids: Array) -> bool:
	for card_id in card_ids:
		if excluded_ids.has(String(card_id)):
			return false
	return true


func _with_chinese_display_names(
	cards: Array[Dictionary],
	display_names: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in cards:
		var card := source.duplicate(true)
		var card_id := String(card.get("id", ""))
		if display_names.has(card_id):
			card["display_name_zh_tw"] = String(display_names[card_id])
		result.append(card)
	return result
