class_name CardDatabase
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://data/cards.json"
const REQUIRED_FIELDS := [
	"id", "name", "type", "rarity", "level", "max_level", "cost", "description",
	"icon_path", "combo_tags", "effect", "upgrade_effects",
	"evolution_condition", "evolution_result", "play_destination", "cooldown_seconds",
]
const VALID_TYPES := ["attack", "skill", "power", "summon", "healing", "status", "ultimate", "combo"]
const VALID_PLAY_DESTINATIONS := ["discard", "exhaust", "cooldown"]

var _cards_by_id: Dictionary = {}
var _ordered_cards: Array[Dictionary] = []


func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> bool:
	_cards_by_id.clear()
	_ordered_cards.clear()
	var document := _read_json_dictionary(path)
	if document.is_empty():
		return false
	var raw_cards: Variant = document.get("cards", [])
	if not raw_cards is Array:
		return false
	for raw_card in raw_cards:
		if not raw_card is Dictionary:
			_clear()
			return false
		var card := (raw_card as Dictionary).duplicate(true)
		card["play_destination"] = String(card.get("play_destination", "discard"))
		card["cooldown_seconds"] = float(card.get("cooldown_seconds", 0.0))
		if not _is_valid_card(card):
			_clear()
			return false
		var card_id := String(card["id"])
		if _cards_by_id.has(card_id):
			_clear()
			return false
		_cards_by_id[card_id] = card
		_ordered_cards.append(card)
	return not _ordered_cards.is_empty()


func get_card(card_id: String) -> Dictionary:
	if not _cards_by_id.has(card_id):
		return {}
	return (_cards_by_id[card_id] as Dictionary).duplicate(true)


func has_card(card_id: String) -> bool:
	return _cards_by_id.has(card_id)


func get_all_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in _ordered_cards:
		result.append(card.duplicate(true))
	return result


func _is_valid_card(card: Dictionary) -> bool:
	for field in REQUIRED_FIELDS:
		if not card.has(field):
			return false
	if String(card["id"]).strip_edges().is_empty() or String(card["name"]).strip_edges().is_empty():
		return false
	if not VALID_TYPES.has(String(card["type"]).to_lower()) or int(card["cost"]) < 0:
		return false
	var play_destination := String(card["play_destination"])
	if not VALID_PLAY_DESTINATIONS.has(play_destination):
		return false
	var cooldown_seconds := float(card["cooldown_seconds"])
	if cooldown_seconds < 0.0 or (play_destination == "cooldown" and cooldown_seconds <= 0.0):
		return false
	if String(card["type"]).to_lower() == "healing" and String(card.get("card_color", "")) != "green":
		return false
	if String(card["rarity"]).strip_edges().is_empty():
		return false
	var level := int(card["level"])
	var max_level := int(card["max_level"])
	if level < 1 or max_level < level:
		return false
	if not card["combo_tags"] is Array or (card["combo_tags"] as Array).is_empty():
		return false
	if not card["effect"] is Dictionary or (card["effect"] as Dictionary).is_empty():
		return false
	if not card["upgrade_effects"] is Array or not _has_visible_level_three_upgrade(card["upgrade_effects"] as Array):
		return false
	if not card["evolution_condition"] is Dictionary or not card["evolution_result"] is String:
		return false
	var icon_path := String(card["icon_path"])
	return not icon_path.is_empty() and ResourceLoader.exists(icon_path)


func _has_visible_level_three_upgrade(upgrades: Array) -> bool:
	for raw_upgrade in upgrades:
		if not raw_upgrade is Dictionary:
			continue
		var upgrade := raw_upgrade as Dictionary
		if int(upgrade.get("level", 0)) == 3 and not String(upgrade.get("mechanic_change", "")).is_empty():
			return true
	return false


func _read_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _clear() -> void:
	_cards_by_id.clear()
	_ordered_cards.clear()
