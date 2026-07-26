extends SceneTree

const EvolutionManagerScript := preload("res://scripts/systems/evolution_manager.gd")
const CardInstanceScript := preload("res://scripts/systems/card_instance.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager = EvolutionManagerScript.new()
	_expect(manager.load_recipes(), "Fusion recipes must load.")
	_expect(manager.get_all_recipes().size() == 6, "The catalog must contain exactly six approved fusion recipes.")
	if not manager.has_method("find_available_fusions"):
		_expect(false, "EvolutionManager must expose instance-based fusion lookup.")
		quit(1)
		return
	var cards: Array = [
		CardInstanceScript.new("guard", 3, "guard-a"),
		CardInstanceScript.new("iron_skin", 3, "stone-a"),
		CardInstanceScript.new("cleave", 3, "cleave-a"),
		CardInstanceScript.new("flame_aura", 3, "aura-a"),
		CardInstanceScript.new("ember_bolt", 3, "ember-fixed"),
	]
	var available: Array[Dictionary] = manager.find_available_fusions(cards)
	_expect(_has_result(available, "fortress_stance"), "Two distinct matching Lv3 instances must offer Unbreakable Stance.")
	_expect(_has_result(available, "inferno_orb"), "Cleave plus Flame Aura must offer Inferno Orb.")
	_expect(not _has_result(available, "gale_lunge"), "A missing material must not offer its fusion.")
	for fusion in available:
		_expect(String(fusion.get("left_instance_id", "")) != String(fusion.get("right_instance_id", "")), "Fusion materials must be two distinct instances.")

	cards[1].level = 2
	available = manager.find_available_fusions(cards)
	_expect(not _has_result(available, "fortress_stance"), "Both fusion materials must be Lv3.")
	_expect(not available.any(func(fusion: Dictionary) -> bool: return String(fusion.get("left_instance_id", "")) == "ember-fixed" or String(fusion.get("right_instance_id", "")) == "ember-fixed"), "Fixed cards must never be fusion materials.")

	if _failures == 0:
		print("PASS: exact two-instance level-three card fusion recipes")
	quit(1 if _failures > 0 else 0)


func _has_result(fusions: Array[Dictionary], result_card_id: String) -> bool:
	return fusions.any(
		func(fusion: Dictionary) -> bool:
			return String(fusion.get("result_card_id", "")) == result_card_id
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
