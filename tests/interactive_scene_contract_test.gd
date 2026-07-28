extends SceneTree

const SCENE_PATHS: Array[String] = [
	"res://tests/fixtures/scenes/NPC.tscn",
	"res://scenes/npc/Merchant.tscn",
	"res://scenes/props/BuildingEntrance.tscn",
	"res://scenes/props/Portal.tscn",
	"res://scenes/props/Chest.tscn",
]

const BASE_SIGNALS: Array[String] = [
	"interaction_available",
	"interaction_unavailable",
	"interacted",
]

func _initialize() -> void:
	var failed := false

	for scene_path in SCENE_PATHS:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("Could not load scene: %s" % scene_path)
			failed = true
			continue

		var instance := scene.instantiate()
		root.add_child(instance)

		failed = _assert_scene_contract(scene_path, instance) or failed
		failed = _assert_interaction_signals(scene_path, instance) or failed
		instance.queue_free()

	quit(1 if failed else 0)

func _assert_scene_contract(scene_path: String, instance: Node) -> bool:
	var failed := false

	for signal_name in BASE_SIGNALS:
		if not instance.has_signal(signal_name):
			push_error("%s missing signal %s" % [scene_path, signal_name])
			failed = true

	if not instance.has_method("interact"):
		push_error("%s missing interact() method" % scene_path)
		failed = true

	if not scene_path.ends_with("BuildingEntrance.tscn"):
		if instance.get_node_or_null("Visual") == null:
			push_error("%s missing Visual node" % scene_path)
			failed = true
		if instance.get_node_or_null("CollisionShape2D") == null:
			push_error("%s missing CollisionShape2D node" % scene_path)
			failed = true

	var interaction_area := instance.get_node_or_null("InteractionArea") as Area2D
	if interaction_area == null:
		push_error("%s missing InteractionArea Area2D" % scene_path)
		failed = true
	elif (
		interaction_area.get_node_or_null("CollisionShape2D") == null
		and interaction_area.get_node_or_null("InteractionCollision") == null
	):
		push_error("%s missing an interaction collision shape" % scene_path)
		failed = true

	if scene_path.ends_with("NPC.tscn") and not instance.has_signal("dialogue_requested"):
		push_error("%s missing dialogue_requested" % scene_path)
		failed = true

	if scene_path.ends_with("Merchant.tscn"):
		if not instance.has_signal("dialogue_requested"):
			push_error("%s missing dialogue_requested" % scene_path)
			failed = true
		if not instance.has_signal("shop_requested"):
			push_error("%s missing shop_requested" % scene_path)
			failed = true

	if scene_path.ends_with("Portal.tscn") and not instance.has_signal("portal_entered"):
		push_error("%s missing portal_entered" % scene_path)
		failed = true
	if scene_path.ends_with("BuildingEntrance.tscn") and not instance.has_signal("building_ui_requested"):
		push_error("%s missing building_ui_requested" % scene_path)
		failed = true

	return failed

func _assert_interaction_signals(scene_path: String, instance: Node) -> bool:
	var failed := false
	var events: Array[String] = []

	instance.interacted.connect(func(_interactive: Node, _interactor: Node) -> void:
		events.append("interacted")
	)

	if instance.has_signal("dialogue_requested"):
		instance.dialogue_requested.connect(func(_npc: Node, _dialogue_id: StringName, _interactor: Node) -> void:
			events.append("dialogue_requested")
		)

	if instance.has_signal("shop_requested"):
		instance.shop_requested.connect(func(_merchant: Node, _shop_id: StringName, _interactor: Node) -> void:
			events.append("shop_requested")
		)

	if instance.has_signal("portal_entered"):
		instance.portal_entered.connect(func(_portal: Node, _target_scene_path: String, _target_spawn_name: StringName, _interactor: Node) -> void:
			events.append("portal_entered")
		)

	if instance.has_signal("chest_opened"):
		instance.chest_opened.connect(func(_chest: Node, _loot_table_id: StringName, _interactor: Node) -> void:
			events.append("chest_opened")
		)
	if instance.has_signal("building_ui_requested"):
		instance.building_ui_requested.connect(
			func(
				_entrance: Node,
				_building_id: StringName,
				_ui_route: StringName,
				_service_id: StringName,
				_interactor: Node
			) -> void:
				events.append("building_ui_requested")
		)

	if not instance.interact(null):
		push_error("%s interact() returned false while enabled" % scene_path)
		failed = true

	if not events.has("interacted"):
		push_error("%s did not emit interacted" % scene_path)
		failed = true

	if scene_path.ends_with("NPC.tscn") and not events.has("dialogue_requested"):
		push_error("%s did not emit dialogue_requested" % scene_path)
		failed = true

	if scene_path.ends_with("Merchant.tscn") and not events.has("shop_requested"):
		push_error("%s did not emit shop_requested" % scene_path)
		failed = true

	if scene_path.ends_with("Portal.tscn") and not events.has("portal_entered"):
		push_error("%s did not emit portal_entered" % scene_path)
		failed = true

	if scene_path.ends_with("Chest.tscn") and not events.has("chest_opened"):
		push_error("%s did not emit chest_opened" % scene_path)
		failed = true
	if (
		scene_path.ends_with("BuildingEntrance.tscn")
		and not events.has("building_ui_requested")
	):
		push_error("%s did not emit building_ui_requested" % scene_path)
		failed = true

	return failed
