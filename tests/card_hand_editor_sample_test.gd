extends SceneTree

const CARD_HAND_SCENE := preload("res://scenes/ui/CardHandUI.tscn")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card_hand := CARD_HAND_SCENE.instantiate()
	var samples: Array = card_hand.call("_editor_sample_cards")

	_expect(samples.size() == 4, "Direct-map editor preview must provide one four-card Combo/Healing hand.")
	if not samples.is_empty():
		_expect(
			not samples.any(func(card: Dictionary) -> bool: return String(card.get("id", "")) == "quickstep"),
			"Editor samples must not present intrinsic Dash as a Quickstep card."
		)
		_expect(
			not _has_direct_dash_sample(samples),
			"Editor samples must not contain a direct Dash card effect."
		)
		var first_card := samples[0] as Dictionary
		_expect(
			String(first_card.get("id", "")) == "guard",
			"Editor slot one should preview Iron Will."
		)
		var samples_are_hand_cards := samples.all(func(card: Dictionary) -> bool:
			return String(card.get("type", "")) in ["combo", "healing"]
		)
		_expect(samples_are_hand_cards, "Every editor hand sample must be Combo or Healing.")
		_expect(not bool(first_card.get("fixed", false)), "Combo previews must not show removed lock treatment.")
		var iron_will := _find_sample(samples, "guard")
		_expect(
			String(iron_will.get("id", "")) == "guard"
			and String(iron_will.get("name", "")) == "Iron Will"
			and String(iron_will.get("type", "")) == "combo",
			"The shared editor preview must use the redesigned Iron Will Combo card."
		)
		_expect(
			String(_find_sample(samples, "healing_light").get("type", "")) == "healing",
			"The editor preview must include a green Healing card."
		)

	var healing_style := card_hand.call("_make_card_style", "HEALING", false) as StyleBoxFlat
	var removed_defense_style := card_hand.call("_make_card_style", "DEFENSE", false) as StyleBoxFlat
	var unknown_style := card_hand.call("_make_card_style", "UNKNOWN", false) as StyleBoxFlat
	_expect(
		healing_style.bg_color.g > healing_style.bg_color.r
		and healing_style.bg_color.g > healing_style.bg_color.b,
		"Shared healing cards must use a green card body."
	)
	_expect(
		removed_defense_style.bg_color == unknown_style.bg_color,
		"The removed Defense taxonomy must not retain a dedicated shared-card color."
	)

	card_hand.free()
	quit(0 if _failures == 0 else 1)


func _find_sample(samples: Array, card_id: String) -> Dictionary:
	for sample in samples:
		if String((sample as Dictionary).get("id", "")) == card_id:
			return sample as Dictionary
	return {}


func _has_direct_dash_sample(samples: Array) -> bool:
	for sample in samples:
		var effect := (sample as Dictionary).get("effect", {}) as Dictionary
		if String(effect.get("kind", "")) in ["dash", "dash_damage"]:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
