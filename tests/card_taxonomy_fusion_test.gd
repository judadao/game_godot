extends SceneTree

const EXPECTED_FUSIONS := {
	"fortress_stance": ["guard", "iron_skin"],
	"gale_lunge": ["dash_strike", "cleave"],
	"time_snare": ["frost_bind", "energy_surge"],
	"renewal": ["healing_light", "blood_pact_combo"],
	"overdrive": ["battle_focus", "flame_aura"],
	"inferno_orb": ["cleave", "flame_aura"],
}

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var database := CardDatabase.new()
	_expect(database.load_catalog(), "The redesigned card catalog must validate.")
	var cards := database.get_all_cards()
	for card in cards:
		_expect(String(card.get("type", "")) != "defense", "Player cards must not use the removed defense type.")
		_expect(not card.has("evolution_condition"), "%s must not carry passive evolution conditions." % card.get("id", ""))
		_expect(not card.has("evolution_result"), "%s must not carry embedded evolution results." % card.get("id", ""))

	_expect(String(database.get_card("quickstep").get("type", "")) == "utility", "Quickstep must be utility.")
	for attack_id in ["dash_strike", "gale_lunge"]:
		_expect(String(database.get_card(attack_id).get("type", "")) == "attack", "%s must be an attack." % attack_id)
	for combo_id in ["guard", "iron_skin", "fortress_stance", "stoneguard_combo"]:
		_expect(String(database.get_card(combo_id).get("type", "")) == "combo", "%s must be a combo card." % combo_id)

	_verify_defensive_card(database, "guard", "Iron Will", 1, 8.0, "super_armor", 4.0)
	_verify_defensive_card(database, "iron_skin", "Stone Form", 2, 12.0, "damage_reduction", 5.0)
	_verify_defensive_card(database, "fortress_stance", "Unbreakable Stance", 4, 18.0, "fortress", 4.0)
	_verify_defensive_card(database, "stoneguard_combo", "Counterguard", 3, 14.0, "counterguard", 6.0)

	for healing_id in ["healing_light", "renewal", "blood_pact_combo", "verdant_renewal"]:
		var healing := database.get_card(healing_id)
		_expect(not healing.is_empty(), "%s must exist." % healing_id)
		_expect(String(healing.get("type", "")) == "healing", "%s must use the green healing type." % healing_id)
		var tags := healing.get("tags", []) as Array
		_expect(
			tags.any(func(tag: Variant) -> bool: return ["restore", "regeneration", "lifesteal", "healing_summon"].has(String(tag))),
			"%s must declare a recovery behavior tag." % healing_id
		)
	_expect(
		bool(database.get_card("healing_light").get("exhaust_on_play", false)),
		"Healing Light must heal immediately, then exhaust on play."
	)

	var game_source := FileAccess.get_file_as_string("res://scripts/managers/game.gd")
	_expect(
		not game_source.contains("evolution_manager.find_available(run_state.card_levels, passives)"),
		"Game must not query instance fusion recipes with shared card levels or passive state."
	)

	var fusion := EvolutionManager.new(database)
	_expect(fusion.load_recipes(), "The fusion catalog must validate.")
	var recipes := fusion.get_all_recipes()
	_expect(recipes.size() == 6, "Exactly six initial fusion recipes must ship.")
	for recipe in recipes:
		var result_id := String(recipe.get("result_card_id", ""))
		_expect(EXPECTED_FUSIONS.has(result_id), "Fusion result %s must be approved." % result_id)
		var material_ids := recipe.get("material_card_ids", []) as Array
		_expect(material_ids.size() == 2, "%s must consume exactly two definitions." % result_id)
		_expect(material_ids[0] != material_ids[1], "%s materials must be distinct." % result_id)
		_expect(int(recipe.get("required_level", 0)) == 3, "%s must require level three materials." % result_id)
		if EXPECTED_FUSIONS.has(result_id):
			_expect(
				_as_sorted_strings(material_ids) == _as_sorted_strings(EXPECTED_FUSIONS[result_id]),
				"%s must use its approved material pair." % result_id
			)

	var owned_instances := [
		{"instance_id": "a", "card_id": "guard", "level": 3},
		{"instance_id": "b", "card_id": "iron_skin", "level": 3},
		{"instance_id": "c", "card_id": "guard", "level": 2},
	]
	var available := fusion.find_available(owned_instances)
	_expect(available.size() == 1, "Only the fully eligible selected pair must be available.")
	if available.size() == 1:
		_expect(
			_as_sorted_strings(available[0].get("material_instance_ids", [])) == ["a", "b"],
			"Fusion availability must identify the exact two instances."
		)

	if _failures == 0:
		print("PASS: card taxonomy, recovery tags, defensive cooldowns, and fusion pairs")
	quit(1 if _failures > 0 else 0)


func _verify_defensive_card(
	database: CardDatabase,
	card_id: String,
	expected_name: String,
	expected_cost: int,
	expected_cooldown: float,
	expected_kind: String,
	expected_duration: float
) -> void:
	var card := database.get_card(card_id)
	var effect := card.get("effect", {}) as Dictionary
	_expect(String(card.get("name", "")) == expected_name, "%s must use its redesigned name." % card_id)
	_expect(int(card.get("cost", -1)) == expected_cost, "%s must keep the approved AP cost." % card_id)
	_expect(is_equal_approx(float(card.get("cooldown", 0.0)), expected_cooldown), "%s must use the approved cooldown." % card_id)
	_expect(String(effect.get("kind", "")) == expected_kind, "%s must use the redesigned effect." % card_id)
	_expect(is_equal_approx(float(effect.get("duration", 0.0)), expected_duration), "%s must use the approved duration." % card_id)


func _as_sorted_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
