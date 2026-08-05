class_name PlayerBlacksmithUI
extends Control

signal opened
signal closed
signal toggled(is_open: bool)
signal canceled
signal craft_requested(recipe_id: StringName)
signal list_for_sale_requested(
	item_kind: StringName,
	item_id: StringName,
	quality: StringName
)
signal resolve_sale_requested
signal upgrade_sword_soul_requested(card_id: StringName)
signal workshop_upgraded

const VALID_SERVICES: Array[StringName] = [
	&"forge",
	&"workshop_upgrade",
	&"sales_table",
]
const RESOURCE_ORDER: Array[StringName] = [
	&"gold",
	&"autumn_wood",
	&"stone",
	&"magic_shard",
	&"autumn_core",
]
const RESOURCE_LABELS := {
	&"gold": "Gold",
	&"autumn_wood": "Wood",
	&"stone": "Stone",
	&"magic_shard": "Shards",
	&"autumn_core": "Cores",
}
const EQUIPMENT_ICON_PATHS := {
	&"iron_sword": "res://assets/ui/equipment/generated/iron_sword.png",
	&"hunter_bow": "res://assets/ui/equipment/generated/hunter_bow.png",
	&"apprentice_staff": "res://assets/ui/equipment/generated/apprentice_staff.png",
	&"leather_armor": "res://assets/ui/equipment/generated/leather_armor.png",
	&"chain_armor": "res://assets/ui/equipment/generated/chain_armor.png",
	&"mage_robe": "res://assets/ui/equipment/generated/mage_robe.png",
	&"swift_ring": "res://assets/ui/equipment/generated/swift_ring.png",
	&"vitality_charm": "res://assets/ui/equipment/generated/vitality_charm.png",
	&"focus_amulet": "res://assets/ui/equipment/generated/focus_amulet.png",
	&"merchant_seal": "res://assets/ui/equipment/generated/merchant_seal.png",
}
const SLOT_LABELS := {
	&"weapon": "Weapon",
	&"armor": "Armor",
	&"accessory": "Accessory",
	&"sword_soul": "Sword Soul",
}

@onready var close_button: Button = %CloseButton
@onready var forge_service_button: Button = %ForgeServiceButton
@onready var upgrade_service_button: Button = %UpgradeServiceButton
@onready var sales_service_button: Button = %SalesServiceButton
@onready var stage_label: Label = %StageLabel
@onready var resource_summary: Label = %ResourceSummary
@onready var workshop_ledger: Label = %WorkshopLedger
@onready var recipe_scroll: ScrollContainer = %RecipeScroll
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var recipe_row_template: Button = %RecipeRowTemplate
@onready var empty_recipe_label: Label = %EmptyRecipeLabel
@onready var forge_workspace: HBoxContainer = %ForgeWorkspace
@onready var upgrade_workspace: HBoxContainer = %UpgradeWorkspace
@onready var sales_workspace: HBoxContainer = %SalesWorkspace
@onready var recipe_preview: TextureRect = %RecipePreview
@onready var recipe_name_label: Label = %RecipeNameLabel
@onready var recipe_type_label: Label = %RecipeTypeLabel
@onready var recipe_status_label: Label = %RecipeStatusLabel
@onready var recipe_description: RichTextLabel = %RecipeDescription
@onready var recipe_cost_label: Label = %RecipeCostLabel
@onready var craft_button: Button = %CraftButton
@onready var equip_button: Button = %EquipButton
@onready var strengthen_button: Button = %StrengthenButton
@onready var action_feedback: Label = %ActionFeedback
@onready var workshop_level_label: Label = %WorkshopLevelLabel
@onready var workshop_unlock_label: Label = %WorkshopUnlockLabel
@onready var workshop_cost_label: Label = %WorkshopCostLabel
@onready var upgrade_button: Button = %UpgradeButton
@onready var sale_item_icon: TextureRect = %SaleItemIcon
@onready var sale_candidate_list: VBoxContainer = %SaleCandidateList
@onready var sale_candidate_template: Button = %SaleCandidateTemplate
@onready var sale_item_name: Label = %SaleItemName
@onready var sale_count_label: Label = %SaleCountLabel
@onready var sale_status_label: Label = %SaleStatusLabel
@onready var customer_status_label: Label = %CustomerStatusLabel
@onready var list_for_sale_button: Button = %ListForSaleButton
@onready var resolve_sale_button: Button = %ResolveSaleButton
@onready var gold_feedback: Label = %GoldFeedback

var _town: RefCounted
var _inventory: RefCounted
var _forge_service: RefCounted
var _context_id: StringName = &"player_blacksmith"
var _blacksmith_service: StringName = &"forge"
var _recipes: Array[Dictionary] = []
var _recipes_explicitly_set := false
var _selected_recipe_id: StringName
var _recipe_by_id: Dictionary = {}
var _recipe_buttons: Array[Button] = []
var _building_buttons: Array[Button] = []
var _sale_state: Dictionary = {}
var _sale_candidates: Array[Dictionary] = []
var _sale_candidate_buttons: Array[Button] = []
var _selected_sale_candidate_key := ""
var _icon_cache: Dictionary = {}
var _resource_value_labels: Dictionary
var _row_normal_style: StyleBox
var _row_selected_style: StyleBox
var _service_normal_style: StyleBox
var _service_selected_style: StyleBox
var _has_action_feedback := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resource_value_labels = {
		&"gold": %GoldAmount,
		&"autumn_wood": %WoodAmount,
		&"stone": %StoneAmount,
		&"magic_shard": %ShardAmount,
		&"autumn_core": %CoreAmount,
	}
	_row_normal_style = recipe_row_template.get_theme_stylebox("normal")
	_row_selected_style = recipe_row_template.get_theme_stylebox("pressed")
	_service_normal_style = upgrade_service_button.get_theme_stylebox("normal")
	_service_selected_style = forge_service_button.get_theme_stylebox("normal")
	_connect_controls()
	gold_feedback.text = ""
	gold_feedback.visible = false
	visible = false
	_apply_service()
	_refresh()


func open() -> void:
	var was_visible := visible
	_blacksmith_service = &"forge"
	_has_action_feedback = false
	gold_feedback.text = ""
	gold_feedback.visible = false
	visible = true
	_apply_service()
	_refresh()
	_focus_current_workspace()
	if not was_visible:
		opened.emit()
		toggled.emit(true)


func close() -> void:
	if not visible:
		return
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and (focused == self or is_ancestor_of(focused)):
		focused.release_focus()
	closed.emit()
	toggled.emit(false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func set_context(context_id: StringName) -> void:
	_context_id = context_id
	if is_node_ready():
		_refresh()


func get_context_id() -> StringName:
	return _context_id


func get_building_id() -> StringName:
	return &"blacksmith"


func set_services(
	town: RefCounted,
	inventory: RefCounted,
	forge_service: RefCounted = null
) -> void:
	_town = town
	_inventory = inventory
	_forge_service = forge_service
	if not _recipes_explicitly_set:
		_recipes = _project_recipes_from_services()
	if is_node_ready():
		_refresh()


func set_recipes(recipes: Array) -> void:
	_recipes_explicitly_set = true
	_recipes.clear()
	for recipe_variant in recipes:
		if recipe_variant is Dictionary:
			var recipe := (recipe_variant as Dictionary).duplicate(true)
			if not StringName(recipe.get("id", "")).is_empty():
				_recipes.append(recipe)
	if is_node_ready():
		_refresh_recipe_catalog()
		_refresh_recipe_detail()


func set_sale_state(state: Dictionary) -> void:
	_sale_state = state.duplicate(true)
	_sale_candidates.clear()
	for candidate_variant in state.get("candidates", []) as Array:
		if candidate_variant is Dictionary:
			_sale_candidates.append((candidate_variant as Dictionary).duplicate(true))
	if _find_sale_candidate(_selected_sale_candidate_key).is_empty():
		_selected_sale_candidate_key = (
			_sale_candidate_key(_sale_candidates[0]) if not _sale_candidates.is_empty() else ""
		)
	if is_node_ready():
		_refresh_sales_table()


func show_sale_result(result: Dictionary) -> void:
	var successful := bool(result.get("ok", result.get("success", false)))
	var gold := int(result.get("gold", result.get("gold_earned", 0)))
	var message := String(result.get("message", ""))
	if message.is_empty():
		message = "Customer purchase complete." if successful else "No sale was completed."
	gold_feedback.text = "+%s GOLD" % _format_number(gold) if successful and gold > 0 else message
	gold_feedback.modulate = (
		Color(1.0, 0.82, 0.32) if successful
		else Color(1.0, 0.58, 0.45)
	)
	gold_feedback.visible = true
	if result.has("sale_state") and result["sale_state"] is Dictionary:
		set_sale_state(result["sale_state"] as Dictionary)


func show_action_result(result: Dictionary) -> void:
	var successful := bool(result.get("ok", result.get("success", false)))
	_set_feedback(String(result.get("message", "Action complete.")), successful)
	_refresh()


func select_blacksmith_service(service_id: StringName) -> void:
	if not VALID_SERVICES.has(service_id):
		return
	_blacksmith_service = service_id
	if not is_node_ready():
		return
	_apply_service()
	_refresh()
	_focus_current_workspace()


func select_service(service_id: StringName) -> void:
	select_blacksmith_service(service_id)


func get_blacksmith_service() -> StringName:
	return _blacksmith_service


func get_selected_service() -> StringName:
	return get_blacksmith_service()


func get_building_button_count() -> int:
	return _building_buttons.size()


func get_equipment_button_count() -> int:
	return _recipe_buttons.size()


func get_resource_text() -> String:
	return resource_summary.text if resource_summary != null else ""


func select_recipe(recipe_id: StringName) -> void:
	if not _recipe_by_id.has(recipe_id):
		return
	_selected_recipe_id = recipe_id
	_has_action_feedback = false
	_refresh_recipe_rows()
	_refresh_recipe_detail()


func select_equipment(item_id: StringName) -> void:
	for recipe_id in _recipe_by_id:
		var recipe := _recipe_by_id[recipe_id] as Dictionary
		if StringName(recipe.get("result_id", recipe.get("item_id", recipe_id))) == item_id:
			select_recipe(recipe_id)
			return


func craft_selected_recipe() -> void:
	if _selected_recipe_id.is_empty():
		return
	craft_requested.emit(_selected_recipe_id)
	_set_feedback("Crafting request sent to the forge.", true)


func purchase_selected_equipment() -> void:
	craft_selected_recipe()


func equip_selected_equipment() -> void:
	var item_id := _selected_equipment_id()
	if item_id.is_empty() or not _inventory_has_method(&"equip"):
		return
	var succeeded := bool(_inventory.call("equip", item_id))
	_set_feedback(
		"Equipment fitted to your loadout." if succeeded
		else "Craft this equipment before equipping it.",
		succeeded
	)
	_refresh()


func strengthen_selected_equipment() -> void:
	var item_id := _selected_equipment_id()
	if item_id.is_empty():
		return
	var recipe := _recipe_by_id.get(_selected_recipe_id, {}) as Dictionary
	if StringName(recipe.get("result_kind", "")) == &"sword_soul":
		upgrade_sword_soul_requested.emit(item_id)
		return
	if not _inventory_has_method(&"upgrade_equipment"):
		return
	var succeeded := bool(_inventory.call("upgrade_equipment", item_id))
	_set_feedback(
		"Tempering complete." if succeeded
		else "Strengthening is unavailable or lacks materials.",
		succeeded
	)
	_refresh()


func upgrade_service_building() -> void:
	request_upgrade()


func request_upgrade() -> bool:
	if not _can_use_town():
		return false
	var succeeded := bool(_town.call("upgrade_building", &"blacksmith"))
	_set_feedback(
		"Workshop upgrade complete." if succeeded
		else "Workshop is complete or requires more materials.",
		succeeded
	)
	if succeeded and _forge_service != null and _forge_service.has_method(
		"set_progression_levels"
	):
		_forge_service.call(
			"set_progression_levels",
			int(_town.call("get_village_stage")),
			_building_level()
		)
		_recipes_explicitly_set = false
	_refresh()
	if succeeded:
		workshop_upgraded.emit()
	return succeeded


func request_list_for_sale() -> void:
	var candidate := _find_sale_candidate(_selected_sale_candidate_key)
	if candidate.is_empty():
		return
	list_for_sale_requested.emit(
		StringName(candidate.get("item_kind", "")),
		StringName(candidate.get("item_id", "")),
		StringName(candidate.get("quality", "common"))
	)


func request_resolve_sale() -> void:
	resolve_sale_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		canceled.emit()
		close()
		get_viewport().set_input_as_handled()


func _connect_controls() -> void:
	close_button.pressed.connect(close)
	forge_service_button.pressed.connect(select_blacksmith_service.bind(&"forge"))
	upgrade_service_button.pressed.connect(select_blacksmith_service.bind(&"workshop_upgrade"))
	sales_service_button.pressed.connect(select_blacksmith_service.bind(&"sales_table"))
	craft_button.pressed.connect(craft_selected_recipe)
	equip_button.pressed.connect(equip_selected_equipment)
	strengthen_button.pressed.connect(strengthen_selected_equipment)
	upgrade_button.pressed.connect(upgrade_service_building)
	list_for_sale_button.pressed.connect(request_list_for_sale)
	resolve_sale_button.pressed.connect(request_resolve_sale)


func _apply_service() -> void:
	forge_workspace.visible = _blacksmith_service == &"forge"
	upgrade_workspace.visible = _blacksmith_service == &"workshop_upgrade"
	sales_workspace.visible = _blacksmith_service == &"sales_table"
	var buttons := {
		&"forge": forge_service_button,
		&"workshop_upgrade": upgrade_service_button,
		&"sales_table": sales_service_button,
	}
	for service_id in buttons:
		var button := buttons[service_id] as Button
		button.add_theme_stylebox_override(
			"normal",
			_service_selected_style if service_id == _blacksmith_service
			else _service_normal_style
		)
	_building_buttons.clear()
	if _blacksmith_service == &"workshop_upgrade":
		_building_buttons.append(upgrade_button)


func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_resources()
	_refresh_stage()
	if not _recipes_explicitly_set:
		_recipes = _project_recipes_from_services()
	_refresh_recipe_catalog()
	_refresh_recipe_detail()
	_refresh_workshop()
	_refresh_sales_table()


func _refresh_resources() -> void:
	var resources: Dictionary = {}
	if _inventory_has_method(&"get_resources"):
		resources = _inventory.call("get_resources") as Dictionary
	var summary_parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		var amount := int(resources.get(String(resource_id), 0))
		var amount_label := _resource_value_labels.get(resource_id) as Label
		if amount_label != null:
			amount_label.text = _format_number(amount)
		summary_parts.append("%s %s" % [RESOURCE_LABELS[resource_id], _format_number(amount)])
	resource_summary.text = "  |  ".join(summary_parts)


func _refresh_stage() -> void:
	if _town != null and _town.has_method("get_village_stage"):
		stage_label.text = "Village Stage %d  ·  Workshop Lv.%d" % [
			int(_town.call("get_village_stage")) + 1,
			_building_level(),
		]
	else:
		stage_label.text = "Private Workshop"
	workshop_ledger.text = "%s  •  %s" % [stage_label.text, resource_summary.text]
	workshop_ledger.tooltip_text = workshop_ledger.text


func _refresh_recipe_catalog() -> void:
	_clear_recipe_rows()
	_recipe_by_id.clear()
	for recipe in _recipes:
		var recipe_id := StringName(recipe.get("id", ""))
		if recipe_id.is_empty():
			continue
		_recipe_by_id[recipe_id] = recipe
		var button := recipe_row_template.duplicate() as Button
		button.name = "Recipe_%s" % String(recipe_id)
		button.visible = true
		button.icon = _recipe_icon(recipe)
		button.tooltip_text = "Inspect %s" % String(recipe.get("name", recipe_id))
		button.pressed.connect(select_recipe.bind(recipe_id))
		button.focus_entered.connect(_on_recipe_focused.bind(recipe_id, button))
		recipe_list.add_child(button)
		_recipe_buttons.append(button)
	empty_recipe_label.visible = _recipe_buttons.is_empty()
	if _selected_recipe_id.is_empty() or not _recipe_by_id.has(_selected_recipe_id):
		_selected_recipe_id = (
			StringName(_recipe_by_id.keys()[0]) if not _recipe_by_id.is_empty()
			else StringName()
		)
	_refresh_recipe_rows()
	_configure_focus_navigation()


func _clear_recipe_rows() -> void:
	for button in _recipe_buttons:
		if is_instance_valid(button):
			button.free()
	_recipe_buttons.clear()


func _refresh_recipe_rows() -> void:
	for button in _recipe_buttons:
		var recipe_id := StringName(button.name.trim_prefix("Recipe_"))
		var recipe := _recipe_by_id.get(recipe_id, {}) as Dictionary
		var kind := String(recipe.get("kind", recipe.get("result_kind", "equipment")))
		var tier := int(recipe.get("tier", recipe.get("quality_tier", 0)))
		var quality_label := String(recipe.get("quality_label", "普通"))
		var unlocked := bool(recipe.get("unlocked", true))
		button.text = "%s\n%s  ·  %s  ·  TIER %d  ·  %s" % [
			String(recipe.get("name", recipe_id)),
			kind.replace("_", " ").to_upper(),
			quality_label,
			tier,
			"READY" if unlocked else "LOCKED",
		]
		var proficiency_level := int(recipe.get("proficiency_level", 0))
		button.text += "  ·  熟練 %d/5" % proficiency_level
		button.disabled = not bool(recipe.get("visible", true))
		button.add_theme_stylebox_override(
			"normal",
			_row_selected_style if recipe_id == _selected_recipe_id else _row_normal_style
		)


func _refresh_recipe_detail() -> void:
	if not _recipe_by_id.has(_selected_recipe_id):
		_show_empty_recipe_detail()
		return
	var recipe := _recipe_by_id[_selected_recipe_id] as Dictionary
	var result_id := StringName(
		recipe.get("result_id", recipe.get("item_id", _selected_recipe_id))
	)
	var kind := StringName(recipe.get("kind", recipe.get("result_kind", "equipment")))
	var is_sword_soul := kind == &"sword_soul"
	var owned := (
		bool(recipe.get("owned", false))
		if is_sword_soul else _has_equipment(result_id)
	)
	var equipped := _is_equipped(result_id, recipe)
	var level := (
		int(recipe.get("level", 0))
		if is_sword_soul else _equipment_level(result_id)
	)
	var unlocked := bool(recipe.get("unlocked", true))
	var cost := recipe.get("cost", recipe.get("craft_cost", {})) as Dictionary
	recipe_preview.texture = _recipe_icon(recipe)
	recipe_name_label.text = String(recipe.get("name", _selected_recipe_id))
	var quality_label := String(recipe.get("quality_label", "普通"))
	var material_tier := String(recipe.get("material_tier", "normal")).to_upper()
	recipe_type_label.text = "%s  ·  %s  ·  %s MATERIAL" % [
		String(SLOT_LABELS.get(kind, String(kind).replace("_", " ").capitalize())).to_upper(),
		quality_label,
		material_tier,
	]
	recipe_status_label.text = "OWNED" if owned else ("READY TO FORGE" if unlocked else "LOCKED")
	recipe_status_label.modulate = (
		Color(0.50, 0.94, 0.74) if owned
		else (Color(0.98, 0.78, 0.35) if unlocked else Color(0.95, 0.48, 0.40))
	)
	var description := String(recipe.get("description", "將這份圖紙鍛造成永久裝備。"))
	var proficiency_level := int(recipe.get("proficiency_level", 0))
	var awakened := bool(recipe.get("blueprint_awakened", false))
	var chances := recipe.get("quality_chances", {}) as Dictionary
	recipe_description.text = (
		"[color=#f0c967][b]%s品質鍛造[/b][/color]\n%s\n\n"
		+ "[color=#9fdde5]圖紙熟練度 Lv.%d / 5[/color]  ·  %s\n"
		+ "稀有 %.0f%%  ·  罕見 %.0f%%  ·  傳奇 %.0f%%"
	) % [
		quality_label,
		description,
		proficiency_level,
		"圖紙已覺醒" if awakened else "Lv.5 時主角會改良圖紙",
		float(chances.get("rare", 0.0)) * 100.0,
		float(chances.get("exceptional", 0.0)) * 100.0,
		float(chances.get("legendary", 0.0)) * 100.0,
	]
	var processing_fee := int(recipe.get("processing_fee", 0))
	var sale_value := int(recipe.get("sale_value", 0))
	recipe_cost_label.text = "MATERIALS  ·  %s\nPROCESSING FEE  ·  GOLD %d%s" % [
		_format_cost(cost),
		processing_fee,
		"  ·  SALE %d" % sale_value if sale_value > 0 else "",
	]
	craft_button.disabled = not unlocked
	craft_button.text = "Forge"
	var is_equipment := not is_sword_soul
	equip_button.visible = is_equipment and owned
	equip_button.disabled = not owned or equipped
	equip_button.text = "Equipped" if equipped else "Equip"
	strengthen_button.visible = owned
	var level_cap := (
		int(_inventory.call("get_max_equipment_level"))
		if is_equipment and _inventory_has_method(&"get_max_equipment_level")
		else 3
	)
	var next_cost := (
		_inventory.call("get_equipment_upgrade_cost", result_id) as Dictionary
		if is_equipment and _inventory_has_method(&"get_equipment_upgrade_cost")
		else {}
	)
	strengthen_button.disabled = (
		level >= level_cap
		or (is_equipment and (not _inventory_has_method(&"upgrade_equipment") or next_cost.is_empty()))
	)
	strengthen_button.text = (
		"已達最高等級" if level >= level_cap
		else "突破素材尚未開放" if is_equipment and next_cost.is_empty()
		else "升級劍魂  ·  Lv.%d" % (level + 1)
		if is_sword_soul
		else "強化裝備  ·  Lv.%d" % (level + 1)
	)
	if not _has_action_feedback:
		action_feedback.text = (
			"Blueprint ready. Forge it when all requirements are met." if unlocked
			else "Upgrade the workshop to unlock this blueprint tier."
		)
		action_feedback.modulate = Color(0.58, 0.69, 0.72)


func _show_empty_recipe_detail() -> void:
	recipe_preview.texture = null
	recipe_name_label.text = "No Blueprint Selected"
	recipe_type_label.text = "FORGE RECIPES"
	recipe_status_label.text = "WAITING"
	recipe_description.text = "Acquire a blueprint, then return here to forge it."
	recipe_cost_label.text = ""
	craft_button.disabled = true
	equip_button.visible = false
	strengthen_button.visible = false


func _refresh_workshop() -> void:
	if not _can_use_town():
		workshop_level_label.text = "Workshop data unavailable"
		workshop_unlock_label.text = "Town service is not connected."
		workshop_cost_label.text = ""
		upgrade_button.disabled = true
		return
	var level := _building_level()
	var max_level := int(_town.call("get_max_building_level", &"blacksmith"))
	var cost := _town.call("get_next_upgrade_cost", &"blacksmith") as Dictionary
	var next_upgrade := _town.call("get_next_upgrade", &"blacksmith") as Dictionary
	var fee_discount := float(_town.call(
		"get_effect_value", &"forge_processing_fee_discount"
	))
	workshop_level_label.text = "Workshop Level %d / %d" % [level, max_level]
	workshop_unlock_label.text = "Current mastery: Tier %d recipes  ·  Processing fee -%d%%" % [
		level,
		roundi(fee_discount * 100.0),
	]
	workshop_cost_label.text = (
		"All workshop improvements complete." if cost.is_empty()
		else "%s\n%s\n\n%s" % [
			String(next_upgrade.get("name", "NEXT UPGRADE")).to_upper(),
			String(next_upgrade.get("description", "")),
			_format_cost_rows(cost),
		]
	)
	upgrade_button.text = "Max Level" if cost.is_empty() else "Upgrade Workshop"
	upgrade_button.disabled = not bool(_town.call("can_upgrade_building", &"blacksmith"))


func _refresh_sales_table() -> void:
	_rebuild_sale_candidates()
	var state := _sale_state
	var selected_candidate := _find_sale_candidate(_selected_sale_candidate_key)
	var item_id := StringName(state.get("item_id", selected_candidate.get("item_id", "")))
	var recipe := _recipe_for_result(item_id)
	var item_name := String(state.get(
		"item_name", selected_candidate.get("item_name", recipe.get("name", item_id))
	))
	var count := int(state.get("crafted_count", selected_candidate.get("count", 0)))
	var status := String(state.get("status", "empty"))
	sale_item_icon.texture = _texture_from_variant(
		state.get("texture", state.get("icon", null))
	)
	if sale_item_icon.texture == null:
		sale_item_icon.texture = _recipe_icon(recipe)
	sale_item_name.text = item_name if not item_name.is_empty() else "Select crafted equipment"
	var quality_label := String(selected_candidate.get("quality_label", ""))
	var unit_price := int(selected_candidate.get("unit_price", 0))
	sale_count_label.text = "SALE INVENTORY  ·  %d AVAILABLE%s" % [
		count,
		"\n%s  ·  %d GOLD EACH" % [quality_label, unit_price]
		if status == "empty" and not selected_candidate.is_empty() else "",
	]
	sale_status_label.text = String(state.get(
		"table_label",
		"Item displayed on the sales table." if status != "empty"
		else "The sales table is empty."
	))
	customer_status_label.text = String(state.get(
		"customer_label",
		"Customer is ready to purchase." if status == "customer_ready"
		else "Waiting for a customer..."
	))
	list_for_sale_button.disabled = (
		status != "empty" or selected_candidate.is_empty() or count <= 0
	)
	resolve_sale_button.disabled = status != "customer_ready"
	gold_feedback.visible = not gold_feedback.text.strip_edges().is_empty()


func _rebuild_sale_candidates() -> void:
	for button in _sale_candidate_buttons:
		if is_instance_valid(button):
			button.free()
	_sale_candidate_buttons.clear()
	for candidate in _sale_candidates:
		var key := _sale_candidate_key(candidate)
		var button := sale_candidate_template.duplicate() as Button
		button.visible = true
		button.focus_mode = Control.FOCUS_ALL
		button.text = "%s  ·  %s  ·  ×%d  ·  %d GOLD" % [
			String(candidate.get("item_name", candidate.get("item_id", ""))),
			String(candidate.get("quality_label", "普通")),
			int(candidate.get("count", 0)),
			int(candidate.get("unit_price", 0)),
		]
		button.button_pressed = key == _selected_sale_candidate_key
		button.pressed.connect(_select_sale_candidate.bind(key))
		sale_candidate_list.add_child(button)
		_sale_candidate_buttons.append(button)


func _select_sale_candidate(key: String) -> void:
	if _find_sale_candidate(key).is_empty():
		return
	_selected_sale_candidate_key = key
	_refresh_sales_table()


func _sale_candidate_key(candidate: Dictionary) -> String:
	return "%s:%s:%s" % [
		candidate.get("item_kind", ""),
		candidate.get("item_id", ""),
		candidate.get("quality", "common"),
	]


func _find_sale_candidate(key: String) -> Dictionary:
	for candidate in _sale_candidates:
		if _sale_candidate_key(candidate) == key:
			return candidate
	return {}


func _project_recipes_from_services() -> Array[Dictionary]:
	if _forge_service != null and _forge_service.has_method("get_available_recipes"):
		var projected := _forge_service.call("get_available_recipes") as Array
		var result: Array[Dictionary] = []
		for entry in projected:
			if entry is Dictionary:
				var projection := (entry as Dictionary).duplicate(true)
				var result_kind := StringName(projection.get("result_kind", projection.get("kind", "")))
				var result_id := StringName(projection.get("result_id", ""))
				if result_kind == &"equipment" and _inventory_has_method(&"get_equipment"):
					var item := _inventory.call("get_equipment", result_id) as Dictionary
					if not item.is_empty():
						projection["name"] = _localized_text(item, "name")
						projection["description"] = "%s\n\n%s" % [
							_localized_text(item, "description"),
							_localized_text(item.get("special_ability", {}) as Dictionary, "description"),
						]
				result.append(projection)
		return result
	if not _inventory_has_method(&"get_equipment_catalog"):
		return []
	var fallback: Array[Dictionary] = []
	for item_variant in _inventory.call("get_equipment_catalog") as Array:
		if not item_variant is Dictionary:
			continue
		var item := (item_variant as Dictionary).duplicate(true)
		var item_id := StringName(item.get("id", ""))
		if item_id.is_empty():
			continue
		fallback.append({
			"id": item_id,
			"result_id": item_id,
			"name": _localized_text(item, "name"),
			"description": _equipment_description(item),
			"kind": item.get("slot", "equipment"),
			"tier": item.get("quality_tier", 0),
			"cost": item.get("purchase_cost", {}),
			"icon_path": EQUIPMENT_ICON_PATHS.get(item_id, ""),
			"unlocked": true,
		})
	return fallback


func _equipment_description(item: Dictionary) -> String:
	var localized := _localized_text(item, "description")
	if not localized.is_empty():
		return localized
	var effects := item.get("effects", {}) as Dictionary
	if effects.is_empty():
		return "A proven workshop design."
	var parts: Array[String] = []
	for effect_id in effects:
		parts.append("%s %+d" % [String(effect_id).capitalize(), int(effects[effect_id])])
	return "  ·  ".join(parts)


func _localized_text(source: Dictionary, field: String) -> String:
	var localized := String(source.get("%s_zh" % field, "")).strip_edges()
	return localized if not localized.is_empty() else String(source.get(field, "")).strip_edges()


func _recipe_icon(recipe: Dictionary) -> Texture2D:
	var recipe_id := StringName(recipe.get("id", ""))
	if _icon_cache.has(recipe_id):
		return _icon_cache[recipe_id] as Texture2D
	var texture := _texture_from_variant(recipe.get("texture", recipe.get("icon", null)))
	if texture == null:
		var path := String(recipe.get(
			"icon_path",
			EQUIPMENT_ICON_PATHS.get(
				StringName(recipe.get("result_id", recipe.get("item_id", recipe_id))),
				""
			)
		))
		if not path.is_empty() and ResourceLoader.exists(path):
			texture = load(path) as Texture2D
	_icon_cache[recipe_id] = texture
	return texture


func _texture_from_variant(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	if value is String and not String(value).is_empty() and ResourceLoader.exists(String(value)):
		return load(String(value)) as Texture2D
	return null


func _selected_equipment_id() -> StringName:
	if not _recipe_by_id.has(_selected_recipe_id):
		return StringName()
	var recipe := _recipe_by_id[_selected_recipe_id] as Dictionary
	if StringName(recipe.get("kind", recipe.get("result_kind", "equipment"))) == &"sword_soul":
		return StringName()
	return StringName(recipe.get("result_id", recipe.get("item_id", _selected_recipe_id)))


func _selected_sale_item_id() -> StringName:
	var state_item := StringName(_sale_state.get("item_id", ""))
	return state_item if not state_item.is_empty() else _selected_equipment_id()


func _recipe_for_result(item_id: StringName) -> Dictionary:
	for recipe in _recipes:
		if StringName(recipe.get("result_id", recipe.get("item_id", recipe.get("id", "")))) == item_id:
			return recipe
	return {}


func _has_equipment(item_id: StringName) -> bool:
	return not item_id.is_empty() and _inventory_has_method(&"has_equipment") and bool(
		_inventory.call("has_equipment", item_id)
	)


func _equipment_level(item_id: StringName) -> int:
	return int(_inventory.call("get_equipment_level", item_id)) if (
		not item_id.is_empty() and _inventory_has_method(&"get_equipment_level")
	) else 0


func _equipment_count(item_id: StringName) -> int:
	if item_id.is_empty():
		return 0
	if _inventory_has_method(&"get_equipment_count"):
		return int(_inventory.call("get_equipment_count", item_id))
	return 1 if _has_equipment(item_id) else 0


func _is_equipped(item_id: StringName, recipe: Dictionary) -> bool:
	if not _has_equipment(item_id) or not _inventory_has_method(&"get_equipped"):
		return false
	var slot := StringName(recipe.get("kind", recipe.get("slot", "")))
	return StringName(_inventory.call("get_equipped", slot)) == item_id


func _building_level() -> int:
	return int(_town.call("get_building_level", &"blacksmith")) if _can_use_town() else 0


func _configure_focus_navigation() -> void:
	forge_service_button.focus_neighbor_bottom = forge_service_button.get_path_to(
		upgrade_service_button
	)
	upgrade_service_button.focus_neighbor_top = upgrade_service_button.get_path_to(
		forge_service_button
	)
	upgrade_service_button.focus_neighbor_bottom = upgrade_service_button.get_path_to(
		sales_service_button
	)
	sales_service_button.focus_neighbor_top = sales_service_button.get_path_to(
		upgrade_service_button
	)
	for index in _recipe_buttons.size():
		var button := _recipe_buttons[index]
		button.focus_neighbor_top = button.get_path_to(
			forge_service_button if index == 0 else _recipe_buttons[index - 1]
		)
		button.focus_neighbor_bottom = button.get_path_to(
			craft_button if index == _recipe_buttons.size() - 1 else _recipe_buttons[index + 1]
		)
		button.focus_neighbor_right = button.get_path_to(craft_button)
	forge_service_button.focus_neighbor_right = forge_service_button.get_path_to(
		_recipe_buttons[0] if not _recipe_buttons.is_empty() else craft_button
	)
	upgrade_service_button.focus_neighbor_right = upgrade_service_button.get_path_to(
		upgrade_button
	)
	sales_service_button.focus_neighbor_right = sales_service_button.get_path_to(
		list_for_sale_button
	)


func _focus_current_workspace() -> void:
	if not visible:
		return
	match _blacksmith_service:
		&"workshop_upgrade":
			upgrade_button.grab_focus()
		&"sales_table":
			list_for_sale_button.grab_focus()
		_:
			if not _recipe_buttons.is_empty():
				_recipe_buttons[0].grab_focus()
			else:
				forge_service_button.grab_focus()


func _on_recipe_focused(recipe_id: StringName, button: Button) -> void:
	select_recipe(recipe_id)
	recipe_scroll.ensure_control_visible(button)


func _set_feedback(message: String, successful: bool) -> void:
	_has_action_feedback = true
	action_feedback.text = message
	action_feedback.modulate = (
		Color(0.52, 0.94, 0.70) if successful
		else Color(1.0, 0.60, 0.46)
	)


func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "No material cost"
	var parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		if cost.has(String(resource_id)):
			parts.append("%s %s" % [
				RESOURCE_LABELS[resource_id],
				_format_number(int(cost[String(resource_id)])),
			])
	return "  ·  ".join(parts)


func _format_cost_rows(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in RESOURCE_ORDER:
		if cost.has(String(resource_id)):
			parts.append("%s %s" % [
				RESOURCE_LABELS[resource_id],
				_format_number(int(cost[String(resource_id)])),
			])
	var rows: Array[String] = []
	for index in range(0, parts.size(), 2):
		rows.append("  ·  ".join(parts.slice(index, mini(index + 2, parts.size()))))
	return "\n".join(rows)


func _can_use_town() -> bool:
	return (
		_town != null
		and _town.has_method("get_building_level")
		and _town.has_method("get_max_building_level")
		and _town.has_method("get_next_upgrade_cost")
		and _town.has_method("can_upgrade_building")
		and _town.has_method("upgrade_building")
	)


func _inventory_has_method(method_name: StringName) -> bool:
	return _inventory != null and _inventory.has_method(method_name)


func _format_number(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "," + text.substr(text.length() - 3, 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result
