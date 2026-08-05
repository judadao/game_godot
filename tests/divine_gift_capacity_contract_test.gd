extends SceneTree

const CATALOG_SIZE := 8
const SLOT_COUNT := 3

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gifts := DivineGiftManager.new()
	_expect(gifts.load_catalog(), "Divine Gift catalog must load.")
	_expect(
		gifts.get_reward_choices(20).size() == CATALOG_SIZE,
		"The reward pool must contain exactly eight Blessings."
	)
	_expect(gifts.get_fusion_recipes().size() == 10, "The first advanced set must contain ten authored fusion forms.")
	var starting_ids := ["resonant_grace", "prismatic_oath", "boundless_font"]
	for gift_id in starting_ids:
		_expect(gifts.add_or_upgrade(gift_id), "Three Blessing slots must accept %s." % gift_id)
	_expect(
		_inventory_ids(gifts.get_inventory()) == starting_ids,
		"The three Blessing slots must preserve acquisition order."
	)
	var recommended := gifts.get_reward_choices(3)
	_expect(
		recommended.size() == 3
			and bool(recommended[0].get("merge_with_owned", false))
			and not (recommended[0].get("fusion_hints", []) as Array).is_empty(),
		"A three-choice Blessing offer must reserve a high-priority authored merge route when one exists."
	)
	var full_snapshot := gifts.get_inventory()
	_expect(
		not gifts.add_or_upgrade("eternal_memory") and gifts.get_inventory() == full_snapshot,
		"A fourth Blessing must not replace any of the three occupied slots."
	)
	_expect(
		_string_set(_choice_ids(gifts.get_reward_choices(20))) == _string_set(starting_ids),
		"A full three-slot inventory may only offer upgrades for owned Blessings."
	)
	for gift_id in starting_ids:
		for _level in 2:
			_expect(gifts.add_or_upgrade(gift_id), "%s must reach level three." % gift_id)
	var offers := gifts.get_fusion_choices()
	_expect(offers.size() == 1, "Only the equipment-free Fire and Lightning recipe may appear initially.")
	_expect(
		gifts.fuse_max_level("prismatic_oath", "boundless_font").is_empty(),
		"An unauthored Blessing pair must never fuse."
	)
	gifts.set_equipped_item_ids(["iron_sword"])
	offers = gifts.get_fusion_choices()
	_expect(
		offers.size() == 2 and _unique_pair_count(offers) == 2,
		"Equipping Iron Sword must unlock the gated Fire and Poison ritual without enabling every pair."
	)
	var evolved := gifts.fuse_max_level("resonant_grace", "prismatic_oath")
	var evolved_id := String(evolved.get("id", ""))
	_expect(
		not evolved_id.is_empty()
			and gifts.get_inventory().size() == 2
			and (evolved.get("basic_attack_statuses", []) as Array).size() == 2,
		"Fusion must replace two slots with one evolved Blessing and inherit both basic-attack statuses."
	)
	_expect(gifts.add_or_upgrade("eternal_memory"), "Fusion must reopen one of the three slots.")
	_expect(gifts.get_inventory().size() == SLOT_COUNT, "The reopened slot must restore a three-Blessing inventory.")
	_expect(gifts.add_or_upgrade(evolved_id), "An evolved Blessing must remain upgradeable at full capacity.")
	var profiles := gifts.get_basic_attack_status_profiles()
	_expect(
		profiles.size() == 4,
		"Fire/lightning fusion plus poison and ice must project four distinct normal-attack states."
	)
	if _failures == 0:
		print("PASS: eight Blessings use three slots and project normal-attack states")
	quit(1 if _failures > 0 else 0)


func _inventory_ids(inventory: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for gift in inventory:
		result.append(String(gift.get("id", "")))
	return result


func _choice_ids(choices: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for choice in choices:
		result.append(String(choice.get("gift_id", "")))
	return result


func _unique_pair_count(offers: Array[Dictionary]) -> int:
	var pairs: Dictionary = {}
	for offer in offers:
		var ids := [String(offer.get("left_gift_id", "")), String(offer.get("right_gift_id", ""))]
		ids.sort()
		pairs["+".join(ids)] = true
	return pairs.size()


func _string_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[String(value)] = true
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
