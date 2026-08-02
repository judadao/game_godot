extends SceneTree

const TOWN_SCENE := preload("res://scenes/maps/town.tscn")
const VISITOR_SCRIPT_PATH := "res://scripts/npc/town_visitor_life.gd"
const VISITOR_CONTRACTS := {
	"VisitorFarmer": {
		"scene": "res://scenes/npc/town/VisitorFarmer.tscn",
		"atlas": "res://assets/town/npc/characters/visitor_farmer_animation_atlas.png",
		"entry_sign": -1.0,
		"resident": "VillagerMale",
	},
	"VisitorMinstrel": {
		"scene": "res://scenes/npc/town/VisitorMinstrel.tscn",
		"atlas": "res://assets/town/npc/characters/visitor_minstrel_animation_atlas.png",
		"entry_sign": 1.0,
		"resident": "Innkeeper",
	},
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var town := TOWN_SCENE.instantiate()
	root.add_child(town)
	await process_frame
	for resident_node in get_nodes_in_group("town_life_npcs"):
		resident_node.set_process(false)
		resident_node.life_enabled = false
	for visitor_name in VISITOR_CONTRACTS:
		var contract: Dictionary = VISITOR_CONTRACTS[visitor_name]
		_assert_scene_contract(String(visitor_name), contract)
		var visitor := town.get_node_or_null("NPCs/%s" % visitor_name)
		_expect(visitor != null, "%s must be composed under Town NPCs." % visitor_name)
		if visitor == null:
			continue
		visitor.set_process(false)
		_assert_runtime_contract(String(visitor_name), visitor, contract)
		_assert_route_cycle(visitor, town.get_node("NPCs/%s" % contract["resident"]))
	town.queue_free()
	await process_frame
	_finish()


func _assert_scene_contract(visitor_name: String, contract: Dictionary) -> void:
	var packed := load(String(contract["scene"])) as PackedScene
	_expect(packed != null, "%s scene must load." % visitor_name)
	if packed == null:
		return
	var visitor := packed.instantiate()
	root.add_child(visitor)
	_expect(visitor is AnimatableBody2D, "%s must use a movable AnimatableBody2D root." % visitor_name)
	_expect(
		visitor.get_script() != null and visitor.get_script().resource_path == VISITOR_SCRIPT_PATH,
		"%s must own the visitor route controller." % visitor_name
	)
	_expect(visitor.is_in_group("NPCs"), "%s must retain Town NPC identity." % visitor_name)
	_expect(visitor.is_in_group("town_visitors"), "%s must join the visitor coordination group." % visitor_name)
	_expect(visitor.get_meta("social_archetype", "") == "visitor", "%s must expose visitor social eligibility." % visitor_name)
	_expect(not visitor.is_in_group("town_life_npcs"), "%s must not become a resident social authority." % visitor_name)
	_expect(not visitor.is_in_group("Interactives"), "%s must not steal building interaction authority." % visitor_name)
	_expect(visitor.get_node_or_null("InteractionArea") == null, "%s must stay display-only." % visitor_name)
	var visual := visitor.get_node_or_null("Visual")
	_expect(visual is TownNPCVisual, "%s must reuse TownNPCVisual animation playback." % visitor_name)
	var body := visitor.get_node_or_null("Visual/VisualRoot/BodySprite") as Sprite2D
	_expect(body != null and body.texture != null, "%s must expose its generated atlas." % visitor_name)
	if body != null and body.texture != null:
		_expect(body.texture.resource_path == contract["atlas"], "%s must use its agreed visitor atlas path." % visitor_name)
		_expect(body.region_enabled and body.region_rect.size == Vector2(144.0, 152.0), "%s atlas cells must match Town NPC playback." % visitor_name)
		var image := body.texture.get_image()
		_expect(image.get_size() == Vector2i(576, 1976), "%s atlas must expose the shared 4x13 visitor grid." % visitor_name)
		_expect(image.detect_alpha() != Image.ALPHA_NONE, "%s atlas must retain transparent sprite backgrounds." % visitor_name)
	visitor.queue_free()


func _assert_runtime_contract(visitor_name: String, visitor: Node, contract: Dictionary) -> void:
	_expect(visitor.has_method("advance_visitor"), "%s route must support deterministic stepping." % visitor_name)
	_expect(visitor.has_method("restart_route"), "%s route must support deterministic restart." % visitor_name)
	var entry := visitor.call("get_entry_position") as Vector2
	var exit := visitor.call("get_exit_position") as Vector2
	_expect(signf(entry.x - 971.0) == float(contract["entry_sign"]), "%s must enter from its authored town edge." % visitor_name)
	_expect(signf(exit.x - 971.0) == -float(contract["entry_sign"]), "%s must leave from the opposite town edge." % visitor_name)
	_expect(absf(exit.x - entry.x) > 2100.0, "%s must traverse the whole town rather than loop locally." % visitor_name)


func _assert_route_cycle(visitor: Node, resident: TownNPCLife) -> void:
	resident.life_enabled = true
	resident.set_process(false)
	visitor.walk_speed = 2400.0
	visitor.greet_seconds = 0.1
	visitor.chat_seconds = 0.2
	visitor.pause_seconds = 0.1
	visitor.cycle_delay_seconds = 0.4
	visitor.call("restart_route", 0.0)
	visitor.call("advance_visitor", 0.01)
	_expect(visitor.call("get_visitor_state") == &"crossing", "Visitor must begin crossing after its offscreen wait.")
	for _step in range(40):
		visitor.call("advance_visitor", 0.05)
		if visitor.call("get_visitor_state") == &"social_greet":
			break
	_expect(visitor.call("get_visitor_state") == &"social_greet", "Visitor must greet its available preferred resident.")
	_expect(visitor.call("get_social_partner") == resident, "Visitor must reserve the authored resident target.")
	_expect(resident.get_life_state() == &"external_chat", "Greeting must temporarily coordinate the resident's chat animation.")
	_expect(visitor.get_node("Visual").get_active_state() == &"greet", "Visitor must visibly greet before beginning a conversation.")
	visitor.call("advance_visitor", 0.15)
	_expect(visitor.call("get_visitor_state") == &"social_chat", "Visitor greeting must continue into a short chat.")
	_expect(visitor.get_node("Visual").get_active_state() == &"chat", "Visitor conversation must play the chat animation.")
	visitor.call("advance_visitor", 0.3)
	_expect(visitor.call("get_visitor_state") == &"exiting", "Visitor must continue toward the opposite edge after chatting.")
	_expect(resident.get_life_state() == &"idle", "Resident must be released after the visitor chat.")
	for _step in range(40):
		visitor.call("advance_visitor", 0.05)
		if visitor.call("get_visitor_state") == &"offscreen_wait":
			break
	_expect(visitor.call("get_visitor_state") == &"offscreen_wait", "Visitor must finish outside town without stalling.")
	_expect(visitor.call("get_completed_passes") == 1, "Visitor must record one complete pass through town.")
	_expect(visitor.call("get_completed_greetings") == 1, "Visitor must record one completed resident greeting.")
	_expect(visitor.position == visitor.call("get_entry_position"), "Completed visitor must reset only after reaching the opposite offscreen edge.")
	resident.life_enabled = false


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: deterministic Town visitor entry, greeting, and exit lifecycle")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
