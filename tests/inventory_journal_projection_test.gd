extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_expect(game.has_method("_inventory_status_projection"), "Game must own the player-status journal projection.")
	_expect(game.has_method("_inventory_equipment_projection"), "Game must own the equipped-slot journal projection.")
	_expect(game.has_method("_inventory_sword_soul_projection"), "Game must project owned Sword Soul instances.")
	_expect(game.has_method("_inventory_compendium_projection"), "Game must assemble the four-section codex projection.")
	_expect(game.has_method("_on_inventory_equip_requested"), "Game must own journal equipment mutations after UI intent emission.")

	if game.has_method("_inventory_status_projection"):
		var status := game.call("_inventory_status_projection") as Dictionary
		for key in ["level", "character_class", "health", "max_health", "mana", "max_mana", "attack", "defense", "speed"]:
			_expect(status.has(key), "Status projection must expose %s." % key)

	if game.has_method("_inventory_equipment_projection"):
		var slots := game.call("_inventory_equipment_projection") as Array
		_expect(slots.size() == 3, "Equipment projection must contain weapon, armor, and accessory slots.")
		for slot_variant in slots:
			var slot := slot_variant as Dictionary
			_expect(String(slot.get("slot", "")) in ["weapon", "armor", "accessory"], "Equipment slot ids must stay canonical.")

	if game.has_method("_inventory_sword_soul_projection"):
		var souls := game.call("_inventory_sword_soul_projection") as Array
		var seen_instances: Dictionary = {}
		for soul_variant in souls:
			var soul := soul_variant as Dictionary
			var instance_id := String(soul.get("instance_id", ""))
			_expect(not instance_id.is_empty(), "Every owned Sword Soul must preserve its CardInstance id.")
			_expect(not seen_instances.has(instance_id), "Sword Soul projection must not duplicate CardInstance ids.")
			seen_instances[instance_id] = true
			_expect(int(soul.get("level", 0)) >= 1, "Every owned Sword Soul must expose its level.")
			_expect(
				String(soul.get("bonus_type", "")) in ["attack", "defense", "healing", "element", "mobility", "ap"],
				"Every owned Sword Soul must project one stable bonus type: %s." % instance_id
			)
			_expect(_contains_han(String(soul.get("bonus_type_label", ""))), "Every owned Sword Soul must project a Chinese bonus-type label: %s." % instance_id)
			_expect(_contains_han(String(soul.get("ability_summary", ""))), "Every owned Sword Soul must project a short Chinese ability note: %s." % instance_id)

	if game.has_method("_inventory_compendium_projection"):
		var compendium := game.call("_inventory_compendium_projection") as Array
		var sections := {"techniques": 0, "enemies": 0, "sword_souls": 0, "equipment": 0}
		var seen_ids: Dictionary = {}
		for entry_variant in compendium:
			var entry := entry_variant as Dictionary
			var section := String(entry.get("section", ""))
			var entry_id := "%s:%s" % [section, String(entry.get("id", ""))]
			_expect(sections.has(section), "Every compendium entry must belong to a supported section.")
			_expect(not String(entry.get("id", "")).is_empty(), "Every compendium entry needs a stable id.")
			_expect(not seen_ids.has(entry_id), "Compendium ids must be unique within their section: %s." % entry_id)
			seen_ids[entry_id] = true
			if sections.has(section):
				sections[section] = int(sections[section]) + 1
			var icon_path := String(entry.get("icon_path", ""))
			_expect(not icon_path.is_empty() and load(icon_path) is Texture2D, "Every compendium row needs a loadable icon: %s." % entry_id)
		_expect(int(sections["enemies"]) == 7, "Enemy codex must project the seven authoritative autumn archetypes.")
		_expect(int(sections["equipment"]) == 10, "Equipment codex must project the ten authoritative equipment definitions.")
		_expect(int(sections["sword_souls"]) >= 4, "Sword Soul codex must include every forge catalog design.")
		_expect(int(sections["techniques"]) > 0, "Technique codex must preserve discovered moves.")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: inventory journal projections")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _contains_han(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false
