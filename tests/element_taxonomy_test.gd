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
