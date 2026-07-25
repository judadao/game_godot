class_name DeckManager
extends RefCounted

var hand_size: int = 8
var max_energy: float = 5.0
var energy: float = 5.0
var draw_pile: Array[String] = []
var hand: Array[String] = []
var discard_pile: Array[String] = []
var exhaust_pile: Array[String] = []
var protected_card_id := ""
var last_play_retained := false

var _card_database: RefCounted


func _init(card_database: RefCounted = null) -> void:
	_card_database = card_database


func start(deck_ids: Array, starting_energy: float = 5.0, shuffle_deck: bool = false) -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	for raw_id in deck_ids:
		var card_id := String(raw_id)
		if _card_database == null or bool(_card_database.call("has_card", card_id)):
			draw_pile.append(card_id)
	max_energy = maxf(0.0, starting_energy)
	energy = max_energy
	if shuffle_deck:
		draw_pile.shuffle()
	if not protected_card_id.is_empty():
		var protected_index := draw_pile.find(protected_card_id)
		if protected_index >= 0:
			hand.append(draw_pile[protected_index])
			draw_pile.remove_at(protected_index)
	draw_cards(hand_size - hand.size())


func draw_cards(count: int) -> Array[String]:
	var drawn: Array[String] = []
	for _draw_index in range(maxi(0, count)):
		if draw_pile.is_empty():
			_reshuffle_discard()
		if draw_pile.is_empty():
			break
		var card_id := draw_pile.pop_front() as String
		hand.append(card_id)
		drawn.append(card_id)
	return drawn


func play_from_hand(index: int) -> Dictionary:
	last_play_retained = false
	if index < 0 or index >= hand.size() or _card_database == null:
		return {}
	var card_id := hand[index]
	var card := _card_database.call("get_card", card_id) as Dictionary
	if card.is_empty():
		return {}
	var cost := maxi(0, int(card.get("cost", 0)))
	if cost > energy:
		return {}
	energy -= cost
	if card_id == protected_card_id:
		last_play_retained = true
		return card
	hand.remove_at(index)
	if String(card.get("type", "")) == "combo":
		exhaust_pile.append(card_id)
	else:
		discard_pile.append(card_id)
	return card


func regenerate_energy(delta: float, rate: float) -> float:
	if delta <= 0.0 or rate <= 0.0 or energy >= max_energy:
		return 0.0
	var previous := energy
	energy = minf(max_energy, energy + delta * rate)
	return energy - previous


func redraw_hand_for_all_energy() -> bool:
	if energy < max_energy or hand.is_empty():
		return false
	energy = 0.0
	var retained: Array[String] = []
	for card_id in hand:
		if card_id == protected_card_id and retained.is_empty():
			retained.append(card_id)
		else:
			discard_pile.append(card_id)
	hand.clear()
	hand.append_array(retained)
	draw_cards(hand_size - hand.size())
	return not hand.is_empty()


func end_turn() -> void:
	var retained: Array[String] = []
	for card_id in hand:
		if card_id == protected_card_id and retained.is_empty():
			retained.append(card_id)
		else:
			discard_pile.append(card_id)
	hand.clear()
	hand.append_array(retained)
	energy = max_energy
	draw_cards(hand_size - hand.size())


func _reshuffle_discard() -> void:
	if discard_pile.is_empty():
		return
	draw_pile.assign(discard_pile)
	discard_pile.clear()
