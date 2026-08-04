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
	_expect(
		builder.has_node(
			"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SkillRecipeSelector"
		),
		"Portal loadout must expose a named-skill selector that can fill required Sword Souls."
	)
	_expect(
		builder.has_method("choose_skill_recipe")
			and builder.has_method("get_selected_skill_recipe_ids")
			and builder.has_method("is_skill_recipe_selectable"),
		"Named-skill selection must expose deterministic compatibility diagnostics."
	)
	var named_skill_list := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SkillRecipeSelector/RecipeScroll/RecipeChoices"
	) as VBoxContainer
	var sword_rain_section := named_skill_list.get_node_or_null(
		"Series_sword_rain"
	) as VBoxContainer
	var sword_rain_tiers := named_skill_list.get_node_or_null(
		"Series_sword_rain/TierChoices"
	) as GridContainer
	var moon_wheel_basic := named_skill_list.get_node_or_null(
		"Series_moon_wheel/TierChoices/Skill_moonwheel_downlight"
	) as Button
	var flowing_fire_choice := named_skill_list.get_node_or_null(
		"Series_fire/TierChoices/Skill_flowing_fire_night"
	) as Button
	_expect(
		named_skill_list.get_child_count() == 13
			and named_skill_list.get_child(0).name == "Series_sword_rain"
			and named_skill_list.get_child(12).name == "Series_shared_branch_vitality"
			and sword_rain_section != null
			and (sword_rain_section.get_node("SeriesHeader") as Label).text.contains("劍雨系列")
			and sword_rain_tiers != null
			and sword_rain_tiers.get_child_count() == 3
			and (sword_rain_tiers.get_child(0) as Button).text.contains("基礎")
			and (sword_rain_tiers.get_child(1) as Button).text.contains("進階")
			and (sword_rain_tiers.get_child(2) as Button).text.contains("大師")
			and flowing_fire_choice != null
			and flowing_fire_choice.text.contains("流火照夜"),
		"Expedition selection must group 39 official skills into 13 series with tier order."
	)
	var sword_rain_basic := sword_rain_tiers.get_child(0) as Button
	_expect(
		moon_wheel_basic != null
			and not sword_rain_basic.focus_neighbor_bottom.is_empty()
			and sword_rain_basic.get_node(sword_rain_basic.focus_neighbor_bottom)
				== moon_wheel_basic,
		"Keyboard down must preserve the same tier while moving to the next series."
	)
	var named_skill_scroll := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SkillRecipeSelector/RecipeScroll"
	) as ScrollContainer
	_expect(
		not named_skill_scroll.get_parent().visible,
		"Named-skill list must not crowd the default four-slot layout."
	)
	builder.call("set_skill_recipe_selector_visible", true)
	await process_frame
	var named_skill_buttons := _collect_named_skill_buttons(named_skill_list)
	_expect(
		named_skill_buttons.size() == 39,
		"Every series section must expose exactly three official skill choices."
	)
	var last_named_skill := named_skill_buttons[-1]
	named_skill_scroll.scroll_vertical = 0
	last_named_skill.grab_focus()
	await process_frame
	await process_frame
	await process_frame
	_expect(
		last_named_skill.has_focus() and named_skill_scroll.scroll_vertical > 0,
		"Keyboard focus must scroll the 39-skill selector to keep the focused name visible."
	)
	_expect(
		builder.has_node("Shade/LoadoutPanel/Margin/Column/TypeLegend"),
		"Portal loadout must explain Healing and Combo colors before selection."
	)
	var slot_row := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/LoadoutSlots"
	) as HBoxContainer
	for slot_variant in slot_row.get_children():
		var slot := slot_variant as Button
		_expect(slot.text.is_empty(), "Loadout slots must use icon cards instead of multiline button text.")
		_expect(
			slot.has_node("Geometry")
				and slot.get_node("Geometry").has_method("get_geometry_state")
				and bool(slot.get_node("Geometry").call("get_geometry_state").get("animated", false)),
			"Every loadout card must own animated antique-gold ritual geometry."
		)
		_expect(
			slot.has_node("Visual/Icon")
				and (slot.get_node("Visual/Icon") as TextureRect).texture != null,
			"Every loadout slot must show its authoritative Sword Soul icon."
		)
		_expect(
			slot.has_node("Visual/Type") and slot.has_node("Visual/Cost"),
			"Every loadout slot must expose type-color and AP labels."
		)
	var auto_attack_selector := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/LoadoutTools/BasicAttackSelector"
	) as OptionButton
	_expect(
		auto_attack_selector.item_count > 0
			and auto_attack_selector.get_item_icon(0) != null,
		"Auto attack selector must use the authoritative attack icon."
	)
	var slots := builder.call("get_slot_card_ids") as Array
	_expect(
		slots == [
			"healing_light", "renewal", "verdant_renewal", "storm_charge",
		],
		"Four slots must preserve a valid loadout with multiple Healing skills."
	)

	builder.call("select_slot", 1)
	await process_frame
	var mixed_choices := builder.call("get_visible_choice_ids") as Array
	var choice_grid := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SwordSoulSelector/SkillChoiceScroll/SkillChoices"
	) as GridContainer
	var first_choice := choice_grid.get_child(0) as Button
	_expect(
		first_choice.text.is_empty()
			and first_choice.has_node("Visual/Icon")
			and (first_choice.get_node("Visual/Icon") as TextureRect).texture != null,
		"Skill choices must be icon cards with readable art instead of emoji-only text."
	)
	_expect(
		_has_card_type(database, mixed_choices, "healing")
			and _has_card_type(database, mixed_choices, "combo"),
		"A slot must offer both Healing and Combo skills while another Healing remains."
	)
	_expect(
		_not_any_present(mixed_choices, NON_FINISHER_SKILL_IDS),
		"Four-slot choices must exclude skills that cannot advance a Finisher recipe."
	)
	var choice_scroll := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SwordSoulSelector/SkillChoiceScroll"
	) as ScrollContainer
	var last_choice := choice_grid.get_child(choice_grid.get_child_count() - 1) as Button
	var last_choice_id := String(mixed_choices[-1])
	var detail := builder.get_node(
		"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SwordSoulSelector/SelectedSkillDetail"
	) as Label
	choice_scroll.scroll_vertical = 0
	last_choice.grab_focus()
	await process_frame
	await process_frame
	await process_frame
	_expect(
		last_choice.has_focus() and choice_scroll.scroll_vertical > 0,
		"Keyboard focus moving down the Sword Soul grid must auto-scroll the viewport."
	)
	_expect(
		detail.text.contains(_display_name(database.get_card(last_choice_id))),
		"Keyboard focus must preview the focused Sword Soul effect before confirmation."
	)
	first_choice.mouse_entered.emit()
	await process_frame
	_expect(
		detail.text.contains(_display_name(database.get_card(String(mixed_choices[0])))),
		"Mouse hover must preview the hovered Sword Soul effect before confirmation."
	)
	_expect(
		not bool(builder.call("choose_card_for_active_slot", "energy_surge")),
		"A non-Finisher skill must not be accepted into a combat loadout slot."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "echo_volley")),
		"Any non-Healing slot must accept an eligible Combo."
	)

	builder.call("select_slot", 0)
	_expect(
		not bool(builder.call("choose_card_for_active_slot", "flame_imbue")),
		"The first slot must remain Healing and reject Combo replacements."
	)
	_expect(
		bool(builder.call("choose_card_for_active_slot", "renewal")),
		"The fixed Healing slot may switch to another Healing Sword Soul."
	)
	builder.call("select_slot", 2)
	var trailing_choices := builder.call("get_visible_choice_ids") as Array
	_expect(
		_has_card_type(database, trailing_choices, "healing")
			and _has_card_type(database, trailing_choices, "combo"),
		"The three trailing Sword Soul slots must accept both formula-eligible types."
	)
	_expect(
		trailing_choices.has("frostburst_imbue")
			and bool(builder.call("choose_card_for_active_slot", "frostburst_imbue")),
		"A trailing slot must accept a Combo because the first Healing slot is fixed."
	)

	var selected := builder.call("get_selected_deck") as Array
	_expect(
		selected == [
			"renewal", "echo_volley", "frostburst_imbue", "storm_charge",
		],
		"Confirmation order must keep fixed Healing first followed by three formula slots."
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

	if builder.has_method("choose_skill_recipe"):
		builder.call("configure", localized_cards, [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		])
		var fixed_healing := String((builder.call("get_slot_card_ids") as Array)[0])
		_expect(
			bool(builder.call("choose_skill_recipe", "wildfire_thunder_tone"))
				and (builder.call("get_slot_card_ids") as Array) == [
					fixed_healing, "flame_imbue", "echo_volley", "storm_charge",
				],
			"Selecting 流火雷音 must fill all three trailing slots while preserving fixed Healing."
		)
		_expect(
			bool(builder.call("is_skill_recipe_selectable", "flowing_fire_night")),
			"A named skill whose requirement already overlaps the three filled slots must remain selectable."
		)
		builder.call("configure", localized_cards, [
			"healing_light", "flame_imbue", "echo_volley", "storm_charge",
		])
		fixed_healing = String((builder.call("get_slot_card_ids") as Array)[0])
		_expect(
			bool(builder.call("choose_skill_recipe", "silent_war_cadence")),
			"Selecting a named skill must fill its required Sword Soul."
		)
		_expect(
			(builder.call("get_slot_card_ids") as Array).has("battle_rhythm"),
			"戰律希聲 must automatically place battle_rhythm in the Sword Soul slots."
		)
		_expect(
			String((builder.call("get_slot_card_ids") as Array)[0]) == fixed_healing,
			"Named-skill selection must never replace the fixed Healing slot."
		)
		_expect(
			bool(builder.call("is_skill_recipe_selectable", "myriad_blades_descend"))
				and bool(builder.call("choose_skill_recipe", "myriad_blades_descend"))
				and (builder.call("get_slot_card_ids") as Array).has("sweeping_reach"),
			"A second compatible named skill must remain normally selectable and fill its non-overlapping requirement."
		)
		_expect(
			bool(builder.call("choose_skill_recipe", "thousand_feather_resonance"))
				and (builder.call("get_slot_card_ids") as Array).has("echo_volley"),
			"A third compatible named skill must use the remaining non-Healing capacity."
		)
		_expect(
			not bool(builder.call("is_skill_recipe_selectable", "moonwheel_downlight")),
			"A fourth distinct requirement must be unavailable because only three formula slots may change."
		)
		var blocked_recipe := builder.get_node_or_null(
			"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SkillRecipeSelector/RecipeScroll/RecipeChoices/Series_moon_wheel/TierChoices/Skill_moonwheel_downlight"
		) as Button
		var selectable_recipe := builder.get_node_or_null(
			"Shade/LoadoutPanel/Margin/Column/SelectionWorkspace/SkillRecipeSelector/RecipeScroll/RecipeChoices/Series_sword_rain/TierChoices/Skill_myriad_blades_descend"
		) as Button
		_expect(
			blocked_recipe != null and blocked_recipe.disabled,
			"An incompatible named skill must remain visible but greyed out instead of disappearing."
		)
		_expect(
			selectable_recipe != null
				and not selectable_recipe.disabled
				and selectable_recipe.get_theme_color("font_color").get_luminance()
					> blocked_recipe.get_theme_color("font_disabled_color").get_luminance(),
			"Compatible named-skill text must remain brighter than an incompatible greyed-out name."
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


func _collect_named_skill_buttons(list: VBoxContainer) -> Array[Button]:
	var result: Array[Button] = []
	for section_variant in list.get_children():
		var section := section_variant as VBoxContainer
		var tiers := section.get_node_or_null("TierChoices") as GridContainer
		if tiers == null:
			continue
		for choice_variant in tiers.get_children():
			result.append(choice_variant as Button)
	return result


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


func _display_name(card: Dictionary) -> String:
	return String(card.get(
		"display_name_zh_tw",
		card.get("name_zh", card.get("name", card.get("id", "")))
	))


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
