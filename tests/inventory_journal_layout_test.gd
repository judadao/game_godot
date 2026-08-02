extends SceneTree

const VIEWPORT_SIZES := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
]
const MODES: Array[StringName] = [&"bag", &"status", &"sword_souls", &"codex"]

var _failures := 0
var _capture_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_capture_dir = OS.get_environment("INVENTORY_JOURNAL_CAPTURE_DIR")
	for viewport_size in VIEWPORT_SIZES:
		await _check_size(viewport_size)
	if _failures == 0:
		print("PASS: four-chapter journal layout at six viewport sizes")
	quit(1 if _failures > 0 else 0)


func _check_size(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ui := (load("res://scenes/ui/inventory/InventoryUI.tscn") as PackedScene).instantiate()
	viewport.add_child(ui)
	await process_frame
	ui.call("set_items", [
		{"id": "iron_sword", "name": "Iron Sword", "category": "gear", "kind_label": "WEAPON EQUIPMENT", "description": "A reliable forged blade ready to equip.", "stats": "Forge level 3\nAttack +4", "equipped": false, "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png"},
		{"id": "wood", "name": "Autumn Wood", "category": "materials", "quantity": 999999, "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Wood_Planks.png"},
		{"id": "map", "name": "泛黃而且名稱很長的秋季古道關鍵地圖", "category": "quest", "quantity": 1, "icon_path": "res://assets/ui/fantasy_icons_16x16/png/Separately/Icon45_1_2.png"},
	])
	ui.call("set_player_status", {
		"level": 99, "character_class": "Wandering Sword Soul Archivist",
		"experience": 999999, "experience_required": 1000000,
		"health": 99999, "max_health": 99999, "mana": 9999, "max_mana": 9999,
		"attack": 9999, "defense": 9999, "speed": 9999.0,
	})
	ui.call("set_equipment_entries", [
		{"slot": "weapon", "id": "iron_sword", "name": "Iron Sword", "level": 3, "stats": "Attack +4", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png"},
		{"slot": "armor", "id": "leather_armor", "name": "Leather Armor", "level": 3, "stats": "Defense +2 · Max Health +10", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0003_Chest.png"},
		{"slot": "accessory", "id": "swift_ring", "name": "Swift Ring", "level": 3, "stats": "Move Speed +8%", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_03.png"},
	])
	ui.call("set_sword_souls", [
		{"instance_id": "journal-layout-flame", "name": "流火附魔", "level": 3, "kind_label": "現有劍魂", "bonus_type_label": "元素", "description": "讓武器斬擊纏上火焰。", "ability_summary": "攻擊傷害 +4、附魔 1.5 秒", "icon_path": "res://assets/props/magic_book/png/Icons/Icon1_big.png"},
		{"instance_id": "journal-layout-guard", "name": "守勢", "level": 2, "kind_label": "現有劍魂", "bonus_type_label": "防禦", "description": "以沉穩架勢抵住迎面衝擊。", "ability_summary": "霸體階級 1、持續 1.5 秒", "icon_path": "res://assets/ui/fantasy_icons_16x16/png/Separately/Icon41_1_2.png"},
		{"instance_id": "journal-layout-heal", "name": "治癒之光", "level": 3, "kind_label": "現有劍魂", "bonus_type_label": "治療", "description": "柔光會尋向傷勢最重的同伴。", "ability_summary": "恢復 20 生命並連鎖治療", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_04.png"},
		{"instance_id": "journal-layout-step", "name": "疾行步法", "level": 1, "kind_label": "現有劍魂", "bonus_type_label": "機動", "description": "借風勢縮短與敵人的距離。", "ability_summary": "移動速度 +10%", "icon_path": "res://assets/ui/fantasy_icons_16x16/png/Separately/Icon48_1_2.png"},
		{"instance_id": "journal-layout-breath", "name": "奧術吐納", "level": 2, "kind_label": "現有劍魂", "bonus_type_label": "AP", "description": "以規律吐納加速行動力恢復。", "ability_summary": "AP 回復 +0.40", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Crafting/Gem_03.png"},
		{"instance_id": "journal-layout-rhythm", "name": "戰鬥節奏", "level": 3, "kind_label": "現有劍魂", "bonus_type_label": "攻擊", "description": "連續斬擊會讓攻勢更加銳利。", "ability_summary": "攻擊傷害 +4", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Equipment/DefaultSet_0000_Weapon.png"},
		{"instance_id": "journal-layout-frost", "name": "霜爆附魔", "level": 2, "kind_label": "現有劍魂", "bonus_type_label": "元素", "description": "冰霜附著斬擊並拖慢敵人。", "ability_summary": "緩速 30%、附魔 1.5 秒", "icon_path": "res://assets/ui/fantasy_icons_16x16/png/Separately/Icon45_1_2.png"},
		{"instance_id": "journal-layout-iron", "name": "鐵骨", "level": 1, "kind_label": "現有劍魂", "bonus_type_label": "防禦", "description": "凝練筋骨以承受更多傷害。", "ability_summary": "防禦 +2", "icon_path": "res://assets/curated/game_own/items/oga_rpg_item_icons/Type Icons/torso_itemType.png"},
	])
	ui.call("set_codex_entries", [
		{"section": "techniques", "id": "ember_bolt", "name": "Ember Bolt", "category": "attacks", "kind_label": "DISCOVERED BASIC ATTACK", "preview_kind": "basic_attack", "element": "normal", "level": 3, "combo_stack": 7, "evolution_layers": ["ember spark", "burning edge", "scarlet arc"], "stack_milestones": [3, 6, 9], "stack_traits": ["warm edge", "double ember", "lasting blaze"], "description": "A fast horizontal sword wave recorded after repeated field use. The journal preserves its combat role, current evolution and all activation notes without hiding long text beneath the painted page curl.", "effect_summary": "Deals 28 base damage in a forward arc; current equipment and active Combo modifiers are projected by Game before use.", "trigger_summary": "Automatic basic attack while a valid target is inside the horizontal engagement range.", "icon_path": "res://assets/props/magic_book/png/Icons/Icon1_big.png"},
	])
	ui.call("open")
	await process_frame
	var panel := ui.get_node("Center/MainPanel") as Control
	var background := panel.get_node("BookBackground") as TextureRect
	var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
	_expect(screen.encloses(_rect(panel)), "Journal panel must stay on-screen at %s." % viewport_size)
	_expect(_rect(panel).is_equal_approx(_rect(background)), "Book background must exactly cover the journal panel at %s." % viewport_size)
	_expect(is_equal_approx(panel.size.x / panel.size.y, 1.5), "Journal panel must preserve the 1.5 source aspect at %s." % viewport_size)
	for mode in MODES:
		ui.call("set_mode", mode)
		await process_frame
		_expect(int(ui.call("get_active_page_count")) == 1, "Exactly one page must be visible in %s at %s." % [mode, viewport_size])
		var page := panel.get_node("Margin/Layout/Pages/%s" % _page_name(mode)) as Control
		_expect(_rect(panel).encloses(_rect(page)), "%s page must stay inside the book at %s." % [mode, viewport_size])
		if page.get_child_count() >= 2:
			var left := page.get_child(0) as Control
			var right := page.get_child(1) as Control
			_expect(not _rect(left).intersects(_rect(right)), "%s page columns must not cross the center gutter at %s." % [mode, viewport_size])
		if mode == &"codex":
			var codex_info := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Info") as Control
			var codex_footer := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/FooterSafe") as Control
			var codex_scroll := panel.get_node("Margin/Layout/Pages/CodexPage/Details/Info/InfoFrame/Scroll") as ScrollContainer
			_expect(_rect(codex_info).encloses(_rect(codex_footer)), "Codex safe footer must stay inside its detail panel at %s." % viewport_size)
			_expect(_rect(codex_info).encloses(_rect(codex_scroll)), "Codex scroll viewport must stay inside its detail panel at %s." % viewport_size)
		elif mode == &"sword_souls":
			var soul_entries := panel.get_node("Margin/Layout/Pages/SwordSoulsPage/Browser/Entries") as ItemList
			var soul_bonus := panel.get_node("Margin/Layout/Pages/SwordSoulsPage/Details/Content/BonusType") as Label
			_expect(soul_entries.max_columns == 2, "Sword Soul shelf must use two visible columns at %s." % viewport_size)
			_expect(soul_entries.item_count == 8, "Sword Soul shelf must keep all projected instances visible at %s." % viewport_size)
			_expect(soul_bonus.text.contains("加乘類型"), "Sword Soul details must keep the bonus-type seal readable at %s." % viewport_size)
		if not _capture_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(_capture_dir)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await process_frame
			var capture_path := _capture_dir.path_join("journal_%s_%dx%d.png" % [mode, viewport_size.x, viewport_size.y])
			_expect(viewport.get_texture().get_image().save_png(capture_path) == OK, "Journal capture must save: %s." % capture_path)
	ui.queue_free()
	viewport.queue_free()
	await process_frame


func _page_name(mode: StringName) -> String:
	match mode:
		&"status":
			return "StatusPage"
		&"sword_souls":
			return "SwordSoulsPage"
		&"codex":
			return "CodexPage"
		_:
			return "InventoryPage"


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
