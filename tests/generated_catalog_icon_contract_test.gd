extends SceneTree

const EXPECTED_SIZE := Vector2i(256, 256)
const CARD_ROOT := "res://assets/ui/autumn/cards/generated/"
const FINISHER_ROOT := "res://assets/ui/finishers/generated/"
const EQUIPMENT_ROOT := "res://assets/ui/equipment/generated/"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_catalog("res://data/cards.json", "cards", CARD_ROOT)
	_check_skill_series_icons()
	_check_catalog("res://data/combo_finishers.json", "recipes", FINISHER_ROOT)
	_check_catalog("res://data/equipment.json", "equipment", EQUIPMENT_ROOT)
	_check_generated_card_filtering()
	if _failures == 0:
		print("PASS: generated catalog icons and new skill-series icon boundary")
	quit(1 if _failures > 0 else 0)


func _check_generated_card_filtering() -> void:
	var file := FileAccess.open("res://data/cards.json", FileAccess.READ)
	var parsed := JSON.parse_string(file.get_as_text()) as Dictionary
	var packed := load("res://scenes/ui/autumn/AutumnBattleCard.tscn") as PackedScene
	_expect(packed != null, "Autumn battle card must load for generated icon filtering")
	if packed == null:
		return
	for card_variant in parsed.get("cards", []) as Array:
		var card := (card_variant as Dictionary).duplicate(true)
		var card_view := packed.instantiate() as Button
		root.add_child(card_view)
		card_view.call("configure", card, "Q", true)
		var icon := card_view.get_node("CardContent/IconStage/Icon") as TextureRect
		_expect(
			icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
			"Generated card art must use linear filtering at HUD scale: %s" % card.get("id", "")
		)
		card_view.free()


func _check_skill_series_icons() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "Skill-series catalog must load for icon validation.")
	var skills := catalog.get_all_skills()
	_expect(skills.size() == 39, "Skill icon boundary must cover all 39 new skills.")
	var paths: Dictionary = {}
	for skill_variant in skills:
		var skill := skill_variant as Dictionary
		var icon_path := String(skill.get("icon_path", "")).strip_edges()
		if icon_path.is_empty():
			continue
		_expect(not paths.has(icon_path), "Authored skill icon paths must stay unique: %s" % icon_path)
		paths[icon_path] = String(skill.get("id", ""))
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
		_expect(texture != null, "Authored skill icon must load: %s" % icon_path)
		if texture != null:
			_expect(Vector2i(texture.get_width(), texture.get_height()) == EXPECTED_SIZE, "Authored skill icon must be 256x256: %s" % icon_path)


func _check_catalog(path: String, key: String, root_path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(file != null, "Icon catalog must open: %s" % path)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "Icon catalog must parse: %s" % path)
	if not parsed is Dictionary:
		return
	var entries: Variant = (parsed as Dictionary).get(key, [])
	_expect(entries is Array, "Icon catalog array must exist: %s.%s" % [path, key])
	if not entries is Array:
		return
	var paths: Dictionary = {}
	for entry_variant in entries as Array:
		if not entry_variant is Dictionary:
			_expect(false, "Icon catalog entries must be dictionaries: %s" % path)
			continue
		var entry := entry_variant as Dictionary
		var entry_id := String(entry.get("id", "")).strip_edges()
		var expected_path := "%s%s.png" % [root_path, entry_id]
		var icon_path := String(entry.get("icon_path", "")).strip_edges()
		_expect(icon_path == expected_path, "%s must own generated icon %s; got %s" % [entry_id, expected_path, icon_path])
		_expect(not paths.has(icon_path), "Generated icon paths must be unique: %s" % icon_path)
		paths[icon_path] = entry_id
		var texture := load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
		_expect(texture != null, "Generated icon must load: %s" % icon_path)
		if texture != null:
			_expect(Vector2i(texture.get_width(), texture.get_height()) == EXPECTED_SIZE, "Generated icon must be 256x256: %s" % icon_path)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
