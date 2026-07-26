extends SceneTree

const CARD_HAND_SCENE := preload("res://scenes/ui/CardHandUI.tscn")
const BASIC_ATTACK_ID := "ember_bolt"
const FIXED_DASH_ID := "quickstep"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var card_hand := CARD_HAND_SCENE.instantiate()
	var samples: Array = card_hand.call("_editor_sample_cards")

	_expect(samples.size() == 8, "Direct-map editor preview must provide two groups of four cards.")
	if not samples.is_empty():
		var first_card := samples[0] as Dictionary
		_expect(
			String(first_card.get("id", "")) == BASIC_ATTACK_ID,
			"Editor group one slot one must remain the fixed ember_bolt basic attack."
		)
		_expect(
			String(first_card.get("type", "")) == "attack",
			"The fixed editor basic card must remain an attack."
		)
		var second_card := samples[1] as Dictionary
		_expect(String(second_card.get("id", "")) == FIXED_DASH_ID, "Editor group one slot two must remain fixed Quickstep.")
		_expect(bool(first_card.get("fixed", false)) and bool(second_card.get("fixed", false)), "Both editor fixed cards must show their lock treatment.")

	card_hand.free()
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
