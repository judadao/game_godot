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
	var candidate_scroll := ui.find_child("CandidateScroll", true, false) as Control
	var price_row := ui.find_child("PriceRow", true, false) as Control
	var list_button := ui.find_child("MarketListButton", true, false) as Button
	_expect(
		candidate_scroll != null
			and candidate_scroll.visible
			and price_row != null
			and not price_row.visible
			and list_button != null
			and not list_button.visible,
		"Restocking must reveal one decision at a time, beginning with the product choice."
	)
	var candidate_list := ui.find_child("MarketCandidateList", true, false) as VBoxContainer
	var first_candidate: Button = null
	if candidate_list != null:
		for child in candidate_list.get_children():
			if child is Button and child.visible:
				first_candidate = child as Button
				break
	if first_candidate != null:
		first_candidate.pressed.emit()
		await process_frame
		_expect(
			not candidate_scroll.visible and price_row.visible and not list_button.visible,
			"Choosing merchandise must replace the list with the pricing decision."
		)
		var fair_button := ui.find_child("MarketFairButton", true, false) as Button
		if fair_button != null:
			fair_button.pressed.emit()
			await process_frame
			_expect(
				not price_row.visible and list_button.visible and list_button.has_focus(),
				"Choosing a price must replace pricing with one focused confirmation action."
			)
			var context_back := ui.find_child("ContextCloseButton", true, false) as Button
			_expect(
				context_back != null and context_back.text == "上一步",
				"The staged stock flow must provide an explicit back action."
			)
			if context_back != null:
				context_back.pressed.emit()
				await process_frame
				_expect(
					price_row.visible and not list_button.visible,
					"Going back from confirmation must return to pricing without closing the shop."
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
