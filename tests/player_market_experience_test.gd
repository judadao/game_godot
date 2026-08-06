extends SceneTree

const BLACKSMITH_SCENE := preload("res://scenes/ui/town/PlayerBlacksmithUI.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ui := BLACKSMITH_SCENE.instantiate() as Control
	root.add_child(ui)
	await process_frame
	ui.call("open")
	await process_frame
	await process_frame

	var forge_button := ui.find_child("ForgeObjectButton", true, false) as Button
	var upgrade_button := ui.find_child("UpgradeObjectButton", true, false) as Button
	var market_button := ui.find_child("MarketObjectButton", true, false) as Button
	_expect(
		forge_button != null
			and forge_button.has_focus()
			and not forge_button.show_behind_parent,
		"The blacksmith must enter with a visible keyboard focus on the forge object."
	)
	_expect(
		forge_button != null
			and upgrade_button != null
			and market_button != null
			and not forge_button.focus_neighbor_right.is_empty()
			and not upgrade_button.focus_neighbor_left.is_empty()
			and not upgrade_button.focus_neighbor_right.is_empty()
			and not market_button.focus_neighbor_left.is_empty(),
		"The three workshop objects need authored left/right keyboard navigation."
	)

	ui.call("select_blacksmith_service", &"sales_table")
	await process_frame
	await process_frame
	var market := ui.find_child("PlayerMarketUI", true, false) as Control
	var store := ui.find_child("StoreInterior", true, false) as Control
	var product_button := ui.find_child("Product1InteractButton", true, false) as Button
	var interior_height := store.size.y if store != null else 0.0
	_expect(
		market != null
			and market.visible
			and product_button != null
			and product_button.has_focus(),
		"Entering the shop must focus the counter restock hotspot."
	)
	if product_button != null:
		product_button.pressed.emit()
	await process_frame
	var dock := ui.find_child("ContextDock", true, false) as Control
	var interior_canvas := ui.find_child("InteriorCanvas", true, false) as Control
	_expect(
		dock != null
			and dock.visible
			and dock.get_parent() == interior_canvas
			and is_equal_approx(store.size.y, interior_height),
		"Restocking must open a side dock over the shop view without compressing it."
	)
	_expect(
		market.has_method("get_active_visitor_count")
			and int(market.call("get_active_visitor_count")) >= 2
			and market.has_method("debug_advance_visitors"),
		"The shop must run at least two reusable NPC visitor routes."
	)
	if market != null and market.has_method("get_visitor_positions") and market.has_method("debug_advance_visitors"):
		var before := market.call("get_visitor_positions") as Array
		market.call("debug_advance_visitors", 3.0)
		var after := market.call("get_visitor_positions") as Array
		_expect(before != after, "Shop visitors must walk between entrance, shelves, and counter.")

	ui.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: blacksmith keyboard and side-dock market visitor experience")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
