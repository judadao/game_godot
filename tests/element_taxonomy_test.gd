extends SceneTree

const EXPECTED_ELEMENTS := [
	"water",
	"fire",
	"wind",
	"lightning",
	"ice",
	"poison",
	"light",
	"dark",
	"normal",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var taxonomy_script := load("res://scripts/systems/element_taxonomy.gd")
	_expect(taxonomy_script != null, "Weapon and blessing elements need one taxonomy authority.")
	if taxonomy_script == null:
		_finish()
		return
	var taxonomy: RefCounted = taxonomy_script.new()
	_expect(
		taxonomy.call("get_all") == EXPECTED_ELEMENTS,
		"Formal elements must be water/fire/wind/lightning/ice/poison/light/dark/normal."
	)
	_expect(
		taxonomy.call("normalize", "flame") == "fire"
			and taxonomy.call("normalize", "earth") == "wind"
			and taxonomy.call("normalize", "storm") == "lightning"
			and taxonomy.call("normalize", "venom") == "poison"
			and taxonomy.call("normalize", "neutral") == "normal",
		"Legacy element aliases must normalize without leaking retired taxonomy values."
	)
	var side_effect_ids: Array[String] = []
	for element in EXPECTED_ELEMENTS:
		var profile := taxonomy.call("get_effect_profile", element) as Dictionary
		_expect(
			not profile.is_empty()
				and String(profile.get("element", "")) == element
				and not String(profile.get("effect_id", "")).is_empty()
				and not String(profile.get("name", "")).is_empty()
				and not String(profile.get("description", "")).is_empty(),
			"Every formal element must expose one readable standalone side effect: %s." % element
		)
		side_effect_ids.append(String(profile.get("effect_id", "")))
	for attacker_element in EXPECTED_ELEMENTS:
		for defender_element in EXPECTED_ELEMENTS:
			_expect(
				is_equal_approx(float(taxonomy.call(
					"get_interaction_multiplier", attacker_element, defender_element
				)), 1.0),
				"Element damage must never gain matchup advantage or resistance: %s -> %s."
					% [attacker_element, defender_element]
			)
	var unique_side_effect_ids := {}
	for side_effect_id in side_effect_ids:
		unique_side_effect_ids[side_effect_id] = true
	_expect(
		unique_side_effect_ids.size() == EXPECTED_ELEMENTS.size(),
		"Each element must have a distinct side-effect identity instead of a counter table."
	)
	var merged := taxonomy.call(
		"apply_attack_side_effects",
		{"target_count": 1, "critical_chance": 0.0},
		EXPECTED_ELEMENTS
	) as Dictionary
	_expect(
		int(merged.get("target_count", 0)) == 2
			and float(merged.get("burn_duration", 0.0)) > 0.0
			and float(merged.get("knockback_multiplier", 0.0)) > 1.0
			and float(merged.get("combo_stun", 0.0)) > 0.0
			and float(merged.get("frost_duration", 0.0)) > 0.0
			and float(merged.get("poison_duration", 0.0)) > 0.0
			and float(merged.get("heal_on_hit_ratio", 0.0)) > 0.0
			and float(merged.get("lifesteal_ratio", 0.0)) > 0.0
			and float(merged.get("critical_chance", 0.0)) > 0.0,
		"All nine standalone side effects must merge without elemental matchup math."
	)

	var inventory_script := load("res://scripts/systems/inventory_manager.gd")
	var inventory: RefCounted = inventory_script.new()
	for weapon_variant in inventory.call("get_equipment_for_slot", &"weapon"):
		var weapon := weapon_variant as Dictionary
		_expect(
			taxonomy.call("is_valid", String(weapon.get("primal_element", ""))),
			"Every weapon must declare one valid primal_element: %s." % weapon.get("id", "")
		)

	var gift_manager := DivineGiftManager.new()
	_expect(gift_manager.load_catalog(), "Divine Gifts must reject elements outside the formal taxonomy.")
	for choice_variant in gift_manager.get_reward_choices(20):
		var choice := choice_variant as Dictionary
		_expect(
			String(choice.get("element", "")) in EXPECTED_ELEMENTS,
			"Blessing reward projection must expose its canonical element."
		)
	for gift_id in ["eternal_memory", "echoing_will"]:
		for _level in 3:
			gift_manager.add_or_upgrade(gift_id)
	var evolved := gift_manager.fuse_max_level("eternal_memory", "echoing_will")
	var evolved_elements := evolved.get("elements", []) as Array
	_expect(
		not evolved.is_empty()
			and String(evolved.get("element", "")) in EXPECTED_ELEMENTS
			and evolved_elements.size() == 2,
		"Evolved blessings must retain canonical component elements instead of inventing 'evolved'."
	)
	for element_variant in evolved_elements:
		_expect(
			String(element_variant) in EXPECTED_ELEMENTS,
			"Evolved blessing component elements must remain canonical."
		)
	_expect(
		String(evolved.get("prefix", "")) == "永劫冰獄的",
		"Canonical ice + dark fusion must retain its authored evolved epithet."
	)
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: weapon and blessing elements share one formal taxonomy")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
