extends SceneTree

const AUTUMN_CARD_PATH := "res://scenes/ui/autumn/AutumnBattleCard.tscn"
const GENERATED_COMBO_ART_ROOT := "res://assets/ui/autumn/cards/generated/"
const EXPECTED_FORMULA_CARD_COUNT := 20
const EXPECTED_ART_SIZE := Vector2i(256, 256)

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var cards := CardDatabase.new()
	var finishers := ComboFinisherCatalog.new()
	_expect(cards.load_catalog(), "卡牌資料必須可載入。")
	_expect(finishers.load_catalog(), "終結技公式必須可載入。")
	_expect(ResourceLoader.exists(AUTUMN_CARD_PATH), "秋季戰鬥卡元件必須可載入。")
	if _failures > 0:
		quit(1)
		return

	var formula_card_ids := _formula_card_ids(finishers.get_all_recipes())
	_expect(
		formula_card_ids.size() == EXPECTED_FORMULA_CARD_COUNT,
		"32 組終結技公式必須涵蓋 20 張唯一 Combo／Healing 劍魂；目前為 %d 張。"
			% formula_card_ids.size()
	)
	var chinese_names: Dictionary = {}
	var art_paths: Dictionary = {}
	var packed_card := load(AUTUMN_CARD_PATH) as PackedScene
	for card_id in formula_card_ids:
		var card := cards.get_card(card_id)
		_expect(not card.is_empty(), "公式引用的劍魂必須存在：%s" % card_id)
		if card.is_empty():
			continue
		var card_type := String(card.get("type", "")).to_lower()
		_expect(
			card_type == "combo" or card_type == "healing",
			"公式卡只能是 Combo 或 Healing 劍魂：%s (%s)" % [card_id, card_type]
		)
		var chinese_name := String(card.get("name_zh", "")).strip_edges()
		var chinese_description := String(card.get("description_zh", "")).strip_edges()
		_expect(_contains_han(chinese_name), "公式劍魂必須有繁中顯示名：%s" % card_id)
		_expect(_contains_han(chinese_description), "公式劍魂必須有繁中描述：%s" % card_id)
		_expect(
			not chinese_names.has(chinese_name),
			"每張公式劍魂必須有唯一中文名；「%s」同時用於 %s 與 %s。"
				% [chinese_name, String(chinese_names.get(chinese_name, "")), card_id]
		)
		if not chinese_name.is_empty():
			chinese_names[chinese_name] = card_id

		var expected_art_path := "%s%s.png" % [GENERATED_COMBO_ART_ROOT, card_id]
		var icon_path := String(card.get("icon_path", "")).strip_edges()
		_expect(
			icon_path == expected_art_path,
			"公式劍魂必須使用依 ID 命名的 generated combo art：%s，實際為 %s"
				% [expected_art_path, icon_path]
		)
		_expect(
			not art_paths.has(icon_path),
			"每張公式劍魂必須使用獨立卡圖，不得共用路徑：%s" % icon_path
		)
		if not icon_path.is_empty():
			art_paths[icon_path] = card_id
		var art_is_loadable := (
			icon_path == expected_art_path
			and ResourceLoader.exists(icon_path)
			and load(icon_path) is Texture2D
		)
		_expect(art_is_loadable, "公式劍魂 generated combo art 必須可載入：%s" % card_id)
		if not art_is_loadable:
			continue
		var texture := load(icon_path) as Texture2D
		_expect(
			Vector2i(texture.get_width(), texture.get_height()) == EXPECTED_ART_SIZE,
			"公式劍魂卡圖必須延續四張參考圖的 256×256 規格：%s" % card_id
		)

		var projected_card := card.duplicate(true)
		projected_card["name"] = chinese_name
		projected_card["description"] = chinese_description
		var card_view := packed_card.instantiate() as Button
		root.add_child(card_view)
		card_view.call("configure", projected_card, "Q", true)
		var name_label := card_view.get_node("CardContent/CardName") as Label
		var icon_view := card_view.get_node("CardContent/IconStage/Icon") as TextureRect
		_expect(
			name_label.text == chinese_name and card_view.tooltip_text == chinese_description,
			"秋季卡 UI 必須投影繁中名稱與描述：%s" % card_id
		)
		_expect(
			icon_view.visible
				and icon_view.texture != null
				and String(icon_view.texture.resource_path) == expected_art_path,
			"秋季卡 UI 必須實際顯示該劍魂的 generated combo art：%s" % card_id
		)
		card_view.free()

	if _failures == 0:
		print("PASS: all formula Combo/Healing cards have unique Traditional Chinese copy and generated art")
	quit(1 if _failures > 0 else 0)


func _formula_card_ids(recipes: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for recipe in recipes:
		for card_id_variant in recipe.get("sequence", []) as Array:
			var card_id := String(card_id_variant)
			if not card_id.is_empty() and not result.has(card_id):
				result.append(card_id)
	return result


func _contains_han(value: String) -> bool:
	for character in value:
		var code := character.unicode_at(0)
		if code >= 0x3400 and code <= 0x9fff:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
