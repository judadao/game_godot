extends SceneTree

const INVENTORY_SCRIPT := preload("res://scripts/systems/inventory_manager.gd")
const TOWN_SCRIPT := preload("res://scripts/systems/town_manager.gd")
const UI_SCENES := [
	{
		"name": "MaterialYardUI",
		"path": "res://scenes/ui/town/MaterialYardUI.tscn",
	},
	{
		"name": "PlayerBlacksmithUI",
		"path": "res://scenes/ui/town/PlayerBlacksmithUI.tscn",
	},
	{
		"name": "TownHallUI",
		"path": "res://scenes/ui/town/TownHallUI.tscn",
	},
	{
		"name": "ShopUI",
		"path": "res://scenes/ui/shop/ShopUI.tscn",
	},
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for descriptor in UI_SCENES:
		await _check_close_and_reopen(descriptor)
	quit(1 if _failures > 0 else 0)


func _check_close_and_reopen(descriptor: Dictionary) -> void:
	var path := String(descriptor["path"])
	_expect(
		ResourceLoader.exists(path, "PackedScene"),
		"%s must exist before lifecycle checks can run." % descriptor["name"]
	)
	if not ResourceLoader.exists(path, "PackedScene"):
		return
	var ui := (load(path) as PackedScene).instantiate() as Control
	root.add_child(ui)
	await process_frame

	_expect(
		ui.has_method("open") and ui.has_method("close") and ui.has_signal("closed"),
		"%s must expose open(), close(), and closed before lifecycle checks."
		% descriptor["name"]
	)
	if not (
		ui.has_method("open")
		and ui.has_method("close")
		and ui.has_signal("closed")
	):
		ui.queue_free()
		await process_frame
		return
	_configure_ui(ui, String(descriptor["name"]))
	var counts := {"opened": 0, "closed": 0, "toggled": 0, "canceled": 0}
	ui.connect("closed", func() -> void: counts["closed"] += 1)
	if ui.has_signal("opened"):
		ui.connect("opened", func() -> void: counts["opened"] += 1)
	if ui.has_signal("toggled"):
		ui.connect("toggled", func(_is_open: bool) -> void: counts["toggled"] += 1)
	if ui.has_signal("canceled"):
		ui.connect("canceled", func() -> void: counts["canceled"] += 1)

	ui.call("open")
	await process_frame
	await process_frame
	_expect(ui.visible, "%s open() must make the screen visible." % descriptor["name"])
	if ui.has_signal("opened"):
		_expect(counts["opened"] == 1, "%s open() must emit opened once." % descriptor["name"])
	if ui.has_signal("toggled"):
		_expect(counts["toggled"] == 1, "%s open() must emit toggled once." % descriptor["name"])
	_expect(
		_focus_is_inside(ui),
		"%s open() must establish keyboard/controller focus." % descriptor["name"]
	)
	var initial_node_count := _recursive_node_count(ui)

	if descriptor["name"] == "ShopUI":
		ui.call("set_quantity", 3)
	elif descriptor["name"] == "PlayerBlacksmithUI":
		ui.call("select_blacksmith_service", &"soul_refinery")

	await _send_cancel(ui, String(descriptor["name"]))
	_expect(not ui.visible, "%s must close on ui_cancel." % descriptor["name"])
	_expect(
		counts["closed"] == 1,
		"%s ui_cancel must emit closed exactly once." % descriptor["name"]
	)
	if ui.has_signal("canceled"):
		_expect(
			counts["canceled"] == 1,
			"%s ui_cancel must emit canceled exactly once." % descriptor["name"]
		)
	_expect(
		not _focus_is_inside(ui),
		"%s close must release focus from hidden descendants." % descriptor["name"]
	)

	ui.call("open")
	await process_frame
	await process_frame
	_expect(ui.visible, "%s must reopen after keyboard close." % descriptor["name"])
	_expect(
		_recursive_node_count(ui) == initial_node_count,
		"%s reopen must not duplicate authored or dynamic controls." % descriptor["name"]
	)
	_expect(
		_focus_is_inside(ui),
		"%s reopen must restore focus to a visible enabled action." % descriptor["name"]
	)

	await _send_cancel(ui, String(descriptor["name"]))
	_expect(
		counts["closed"] == 2,
		"%s repeated open/close must emit closed once per transition."
		% descriptor["name"]
	)
	if ui.has_signal("opened"):
		_expect(counts["opened"] == 2, "%s must emit opened once per reopen." % descriptor["name"])
	if ui.has_signal("toggled"):
		_expect(counts["toggled"] == 4, "%s must emit toggled once per transition." % descriptor["name"])
	if ui.has_signal("canceled"):
		_expect(counts["canceled"] == 2, "%s must emit canceled once per keyboard close." % descriptor["name"])
	ui.queue_free()
	await process_frame


func _configure_ui(ui: Control, ui_name: String) -> void:
	if ui_name == "ShopUI":
		_expect(ui.has_method("set_items"), "ShopUI must expose set_items() for reopen checks.")
		if ui.has_method("set_items"):
			ui.call("set_items", [{
				"id": "soul_edge",
				"name": "Soul Edge",
				"description": "Lifecycle fixture",
				"price": 10,
				"stock": 5,
				"owned_count": 5,
			}])
		return
	var inventory: RefCounted = INVENTORY_SCRIPT.new()
	var town: RefCounted = TOWN_SCRIPT.new(inventory)
	_expect(
		ui.has_method("set_services"),
		"%s must expose set_services() for isolated reopen checks." % ui_name
	)
	if ui.has_method("set_services"):
		ui.call("set_services", town, inventory)


func _send_cancel(ui: Control, ui_name: String) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	_expect(
		ui.has_method("_unhandled_input"),
		"%s must handle ui_cancel through Godot's unhandled input path." % ui_name
	)
	if ui.has_method("_unhandled_input"):
		ui.call("_unhandled_input", event)
	else:
		ui.call("close")
	await process_frame


func _focus_is_inside(ui: Control) -> bool:
	var focused := ui.get_viewport().gui_get_focus_owner()
	return focused != null and (focused == ui or ui.is_ancestor_of(focused))


func _recursive_node_count(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _recursive_node_count(child)
	return total


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
