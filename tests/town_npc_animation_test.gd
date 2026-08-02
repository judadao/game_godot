extends SceneTree

const NPC_SCENE_PATHS := {
	"Mayor": "res://scenes/npc/town/Mayor.tscn",
	"VillagerMale": "res://scenes/npc/town/MaleVillager.tscn",
	"EquipmentBlueprintMerchant": "res://scenes/npc/town/FemaleVillager.tscn",
	"Guard": "res://scenes/npc/town/TownGuard.tscn",
	"ItemMerchant": "res://scenes/npc/town/PotionMerchant.tscn",
	"Blacksmith": "res://scenes/npc/town/Blacksmith.tscn",
	"Innkeeper": "res://scenes/npc/town/Innkeeper.tscn",
}
const INTERACTIVE_NPC_SCENE_PATHS := {
	"GenericMerchant": "res://scenes/npc/Merchant.tscn",
	"SeatedTrailMerchant": "res://scenes/maps/autumn_safe/components/SeatedTrailMerchant.tscn",
}
const VISITOR_NPC_SCENE_PATHS := {
	"VisitorFarmer": "res://scenes/npc/town/VisitorFarmer.tscn",
	"VisitorMinstrel": "res://scenes/npc/town/VisitorMinstrel.tscn",
}
const CHARACTER_TEXTURE_ROOT := "res://assets/town/npc/characters/"
const RESIDENT_CHARACTER_ASSETS := [
	"traveler", "witch", "guard", "grocer", "scientist", "innkeeper",
]
const VISITOR_CHARACTER_ASSETS := ["visitor_farmer", "visitor_minstrel"]
const GENERATED_CHARACTER_ASSETS := RESIDENT_CHARACTER_ASSETS + VISITOR_CHARACTER_ASSETS
const GENERATED_ROWS := [0, 1, 3, 9, 10, 11, 12]
const CHARACTER_ACTION_ROWS := [13, 14, 15, 16]
const ATLAS_CELL_SIZE := Vector2i(144, 152)
const REQUIRED_STATES: Array[StringName] = [
	&"idle", &"walk", &"sit", &"chat", &"laugh",
	&"happy", &"sad", &"surprised", &"angry",
	&"idle_look", &"idle_stretch", &"greet", &"work",
]

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_generated_animation_assets()
	for npc_name in NPC_SCENE_PATHS:
		if npc_name == "Mayor":
			_assert_priest_scene(String(NPC_SCENE_PATHS[npc_name]))
		else:
			_assert_npc_scene(String(npc_name), String(NPC_SCENE_PATHS[npc_name]))
	for npc_name in INTERACTIVE_NPC_SCENE_PATHS:
		_assert_npc_scene(String(npc_name), String(INTERACTIVE_NPC_SCENE_PATHS[npc_name]))
	_assert_town_integration()
	await _capture_review_frames()
	_finish()


func _assert_priest_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "Priest Town scene must load.")
	if packed == null:
		return
	var priest := packed.instantiate()
	root.add_child(priest)
	_expect(priest is AnimatableBody2D, "Priest must use a movable AnimatableBody2D root.")
	_expect(
		priest.get_script() != null
		and priest.get_script().resource_path == "res://scripts/npc/priest_town_behavior.gd",
		"Priest must own the Town round-trip behavior controller."
	)
	var visual := priest.get_node_or_null("Visual")
	_expect(
		visual != null
		and visual.get_script() != null
		and visual.get_script().resource_path == "res://scripts/npc/priest_animated_sprite.gd",
		"Priest must use the dedicated eight-frame full-pose animator."
	)
	var body := priest.get_node_or_null("Visual/CharacterSprite") as Sprite2D
	_expect(
		body != null
		and body.texture != null
		and body.texture.resource_path == "res://assets/town/npc/priest/priest_animation_atlas.png"
		and body.hframes == 8
		and body.vframes == 8,
		"Priest must expose the approved 8x8 full-pose animation atlas."
	)
	if body != null and body.texture != null:
		_expect(body.texture.get_size() == Vector2(3072, 4096), "Priest atlas must retain eight authored rows.")
	for action in [&"prayer", &"bless", &"comfort", &"share_goods", &"courage"]:
		_expect(visual.call("play_animation", action, true), "Priest must support %s." % action)
	priest.queue_free()


func _assert_npc_scene(npc_name: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s scene must load." % npc_name)
	if packed == null:
		return
	var npc := packed.instantiate()
	root.add_child(npc)
	if scene_path.begins_with("res://scenes/npc/town/"):
		_expect(npc is TownNPCLife, "%s must use the reusable living-Town controller." % npc_name)
		_expect(npc.is_in_group("town_life_npcs"), "%s must join the Town life coordination group." % npc_name)
		_expect(
			npc.get_script() != null
			and npc.get_script().resource_path == "res://scripts/npc/town_npc_life.gd",
			"%s must own autonomous walk, social chat, idle, and emote behavior." % npc_name
		)
	var visual := npc.get_node_or_null("Visual")
	_expect(visual != null, "%s must keep the stable Visual node." % npc_name)
	if visual == null:
		npc.queue_free()
		return
	_expect(
		visual.get_script() != null
		and visual.get_script().resource_path == "res://scripts/npc/town_npc_visual.gd",
		"%s must use the reusable Town NPC animation controller." % npc_name
	)
	var body := visual.get_node_or_null("VisualRoot/BodySprite") as Sprite2D
	_expect(body != null and body.texture != null, "%s must expose one textured body sprite." % npc_name)
	if body != null and body.texture != null:
		_expect(
			body.texture.resource_path.begins_with(CHARACTER_TEXTURE_ROOT),
			"%s must use a new concept/characters-derived cutout." % npc_name
		)
		_expect(
			body.texture.resource_path.ends_with("_animation_atlas.png")
				and body.region_enabled
				and body.region_rect.size == Vector2(144.0, 152.0),
			"%s must use authored world-scale atlas frames instead of one static cutout." % npc_name
		)
		var image := body.texture.get_image()
		_expect(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF], "%s cutout must retain alpha." % npc_name)
		_expect(_has_transparent_pixel(image), "%s cutout must not retain its concept background." % npc_name)
	_expect(visual.has_method("get_supported_states"), "%s must expose animation states." % npc_name)
	if visual.has_method("get_supported_states"):
		var supported := visual.call("get_supported_states") as Array
		for state in REQUIRED_STATES:
			_expect(supported.has(state), "%s must support %s animation." % [npc_name, state])
	_expect(visual.has_method("play_state") and visual.has_method("advance_animation"), "%s animation must be testable." % npc_name)
	if visual.has_method("play_state") and visual.has_method("advance_animation"):
		visual.call("play_state", &"idle")
		var before := visual.call("get_animation_snapshot") as Dictionary
		visual.call("advance_animation", 0.45)
		var after := visual.call("get_animation_snapshot") as Dictionary
		_expect(before != after, "%s idle must use multiple authored cadence poses." % npc_name)
		for state in REQUIRED_STATES:
			visual.call("play_state", state)
			_expect(visual.call("get_active_state") == state, "%s must enter %s." % [npc_name, state])
	npc.queue_free()


func _assert_generated_animation_assets() -> void:
	for asset_name in GENERATED_CHARACTER_ASSETS:
		var atlas_path := "%s%s_animation_atlas.png" % [CHARACTER_TEXTURE_ROOT, asset_name]
		var motion_path := (
			"%smotion_strips_v2/%s_motion.png" % [CHARACTER_TEXTURE_ROOT, asset_name]
			if RESIDENT_CHARACTER_ASSETS.has(asset_name)
			else "%smotion_strips_v3/%s_base.png" % [CHARACTER_TEXTURE_ROOT, asset_name]
		)
		var extra_path := "%smotion_strips_v3/%s_extra.png" % [CHARACTER_TEXTURE_ROOT, asset_name]
		_expect(ResourceLoader.exists(atlas_path), "%s generated atlas must exist." % asset_name)
		_expect(ResourceLoader.exists(motion_path), "%s reviewed full-pose source strip must exist." % asset_name)
		_expect(ResourceLoader.exists(extra_path), "%s reviewed extra-action strip must exist." % asset_name)
		var texture := load(atlas_path) as Texture2D
		if texture == null:
			continue
		var image := texture.get_image()
		var expected_rows := 17 if asset_name in ["witch", "scientist"] else 13
		_expect(image.get_size() == Vector2i(576, expected_rows * ATLAS_CELL_SIZE.y), "%s atlas must use its approved state grid." % asset_name)
		var reviewed_rows := GENERATED_ROWS.duplicate()
		if asset_name in ["witch", "scientist"]:
			reviewed_rows.append_array(CHARACTER_ACTION_ROWS)
		for row in reviewed_rows:
			var frame_hashes: Dictionary = {}
			for column in range(4):
				var rect := Rect2i(column * ATLAS_CELL_SIZE.x, row * ATLAS_CELL_SIZE.y, ATLAS_CELL_SIZE.x, ATLAS_CELL_SIZE.y)
				var frame := image.get_region(rect)
				var used := frame.get_used_rect()
				_expect(used.has_area(), "%s row %d frame %d must not be empty." % [asset_name, row, column])
				_expect(
					used.position.x > 0 and used.position.y > 0
					and used.end.x < ATLAS_CELL_SIZE.x and used.end.y < ATLAS_CELL_SIZE.y,
					"%s row %d frame %d must not clip the cell edge." % [asset_name, row, column]
				)
				frame_hashes[hash(frame.get_data())] = true
			_expect(frame_hashes.size() >= 3, "%s row %d must contain authored pose changes." % [asset_name, row])
		if RESIDENT_CHARACTER_ASSETS.has(asset_name):
			for column in range(4):
				var sit_frame := image.get_region(Rect2i(column * ATLAS_CELL_SIZE.x, 2 * ATLAS_CELL_SIZE.y, ATLAS_CELL_SIZE.x, ATLAS_CELL_SIZE.y))
				var sit_used := sit_frame.get_used_rect()
				_expect(
					sit_used.size.y >= 116 and sit_used.size.y <= 122,
					"%s sit frame %d must preserve adult torso scale and a readable seat silhouette." % [asset_name, column]
				)


func _assert_town_integration() -> void:
	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	root.add_child(town)
	var atlas_paths: Dictionary = {}
	for npc_name in NPC_SCENE_PATHS:
		var npc := town.get_node_or_null("NPCs/%s" % npc_name)
		_expect(npc != null, "Town must retain %s placement." % npc_name)
		if npc != null:
			_expect(npc.scene_file_path == NPC_SCENE_PATHS[npc_name], "%s must remain scene-linked." % npc_name)
			_expect(not npc.is_in_group("Interactives"), "%s must not steal building interactions." % npc_name)
			var body := (
				npc.get_node("Visual/CharacterSprite") as Sprite2D
				if npc_name == "Mayor"
				else npc.get_node("Visual/VisualRoot/BodySprite") as Sprite2D
			)
			atlas_paths[body.texture.resource_path] = true
	_expect(atlas_paths.size() == NPC_SCENE_PATHS.size(), "All seven Town roles must use distinct world animation atlases.")
	town.queue_free()


func _has_transparent_pixel(image: Image) -> bool:
	for y in range(0, image.get_height(), maxi(1, image.get_height() / 32)):
		for x in range(0, image.get_width(), maxi(1, image.get_width() / 32)):
			if image.get_pixel(x, y).a < 0.05:
				return true
	return false


func _capture_review_frames() -> void:
	var capture_directory := OS.get_environment("TOWN_NPC_CAPTURE_DIR")
	if capture_directory.is_empty():
		return
	_expect(
		DirAccess.make_dir_recursive_absolute(capture_directory) == OK,
		"Town NPC review capture directory must be writable."
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1942, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var town := (load("res://scenes/maps/town.tscn") as PackedScene).instantiate()
	_disable_cameras(town)
	viewport.add_child(town)
	await process_frame
	await process_frame
	await process_frame
	_save_review_frame(viewport, capture_directory.path_join("town_npcs_idle"))
	var showcase_states: Array[StringName] = [
		&"sit", &"chat", &"laugh", &"happy", &"sad", &"surprised", &"angry",
	]
	var index := 0
	for npc_name in NPC_SCENE_PATHS:
		var visual := town.get_node("NPCs/%s/Visual" % npc_name)
		if npc_name == "Mayor":
			visual.call("play_animation", &"front_chat", true)
			visual.call("set_frame_for_review", 3)
		else:
			var actor := town.get_node("NPCs/%s" % npc_name) as TownNPCLife
			actor.life_enabled = false
			actor.set_process(false)
			visual.set("ambient_enabled", false)
			visual.call("play_state", showcase_states[index])
			visual.call("advance_animation", 0.4)
		index += 1
	await process_frame
	await process_frame
	_save_review_frame(viewport, capture_directory.path_join("town_npcs_showcase"))
	var priest_visual := town.get_node("NPCs/Mayor/Visual")
	priest_visual.call("play_animation", &"prayer", true)
	priest_visual.call("set_frame_for_review", 3)
	var witch_visual := town.get_node("NPCs/EquipmentBlueprintMerchant/Visual")
	witch_visual.call("play_state", &"cast_ward")
	witch_visual.call("advance_animation", 2.0)
	var scientist_visual := town.get_node("NPCs/Blacksmith/Visual")
	scientist_visual.call("play_state", &"malfunction")
	scientist_visual.call("advance_animation", 2.0)
	await process_frame
	await process_frame
	_save_review_frame(viewport, capture_directory.path_join("town_character_actions"))
	witch_visual.call("advance_animation", 3.0)
	scientist_visual.call("advance_animation", 3.0)
	await process_frame
	await process_frame
	_save_review_frame(viewport, capture_directory.path_join("town_character_actions_settled"))
	town.call("set_time_of_day_progress", 0.05)
	var priest := town.get_node("NPCs/Mayor")
	priest.set("home_wait_seconds", 0.1)
	priest.call("advance_behavior", 0.11)
	var witch := town.get_node("NPCs/EquipmentBlueprintMerchant") as TownNPCLife
	witch.call("request_character_activity", &"read_grimoire", 12.0)
	var scientist := town.get_node("NPCs/Blacksmith") as TownNPCLife
	scientist.call("request_character_activity", &"write_notes", 9.0)
	witch.npc_visual.call("advance_animation", 2.0)
	scientist.npc_visual.call("advance_animation", 2.0)
	await process_frame
	await process_frame
	_save_review_frame(viewport, capture_directory.path_join("town_profile_runtime"))
	viewport.queue_free()
	await process_frame
	await _save_state_sheet(capture_directory)
	await _save_character_action_sheet(capture_directory)


func _disable_cameras(node: Node) -> void:
	if node is Camera2D:
		(node as Camera2D).enabled = false
	for child in node.get_children():
		_disable_cameras(child)


func _save_review_frame(viewport: SubViewport, path_prefix: String) -> void:
	var frame := viewport.get_texture().get_image()
	_expect(frame.save_png("%s_full.png" % path_prefix) == OK, "Town NPC full-frame capture must save.")
	var x_edges := [0, 647, 1294, frame.get_width()]
	var y_edges := [0, 360, frame.get_height()]
	for row in range(2):
		for column in range(3):
			var region := Rect2i(
				x_edges[column],
				y_edges[row],
				x_edges[column + 1] - x_edges[column],
				y_edges[row + 1] - y_edges[row]
			)
			var slice := frame.get_region(region)
			var slice_path := "%s_r%d_c%d.png" % [path_prefix, row + 1, column + 1]
			_expect(slice.save_png(slice_path) == OK, "Town NPC review slice must save: %s" % slice_path)


func _save_state_sheet(capture_directory: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2210, 1430)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("26211d")
	backdrop.size = Vector2(viewport.size)
	viewport.add_child(backdrop)
	var states: Array[StringName] = REQUIRED_STATES.duplicate()
	var row := 0
	var state_sheet_scenes := NPC_SCENE_PATHS.duplicate()
	state_sheet_scenes.merge(VISITOR_NPC_SCENE_PATHS)
	for npc_name in state_sheet_scenes:
		for column in range(states.size()):
			var npc := (load(String(state_sheet_scenes[npc_name])) as PackedScene).instantiate()
			var desired_position := Vector2(85.0 + column * 170.0, 148.0 + row * 156.0)
			if npc is TownVisitorLife:
				npc.set("visitor_enabled", false)
			viewport.add_child(npc)
			# TownVisitorLife initializes at its offscreen route entry in _ready().
			# Restore the authored review-grid position after that initialization.
			npc.position = desired_position
			var visual := npc.get_node("Visual")
			if npc_name == "Mayor":
				var priest_animation: StringName = (
					&"front_idle" if column == 0
					else &"front_chat" if column < 4
					else &"side_walk" if column < 6
					else &"side_chat"
				)
				visual.call("play_animation", priest_animation, true)
				visual.call("set_frame_for_review", column % 8)
			else:
				if npc is TownNPCLife:
					npc.set("life_enabled", false)
				elif npc is TownVisitorLife:
					npc.set("visitor_enabled", false)
				npc.set_process(false)
				visual.set("ambient_enabled", false)
				visual.call("play_state", states[column])
				visual.call("advance_animation", 0.4)
		row += 1
	await process_frame
	await process_frame
	await process_frame
	var output_path := capture_directory.path_join("town_npc_animation_state_sheet.png")
	_expect(viewport.get_texture().get_image().save_png(output_path) == OK, "Town NPC state sheet must save.")
	viewport.queue_free()
	await process_frame


func _save_character_action_sheet(capture_directory: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 500)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var backdrop := ColorRect.new()
	backdrop.color = Color("26211d")
	backdrop.size = Vector2(viewport.size)
	viewport.add_child(backdrop)
	var scenes := [
		["res://scenes/npc/town/Mayor.tscn", [&"prayer", &"bless", &"comfort", &"share_goods", &"courage"]],
		["res://scenes/npc/town/FemaleVillager.tscn", [&"read_grimoire", &"brew_potion", &"divination", &"cast_ward", &"hidden_concern"]],
		["res://scenes/npc/town/Blacksmith.tscn", [&"write_notes", &"measure", &"assemble", &"malfunction", &"inspiration", &"concern"]],
	]
	for row in range(scenes.size()):
		var scene_spec: Array = scenes[row]
		var actions: Array = scene_spec[1]
		for column in range(actions.size()):
			var npc := (load(String(scene_spec[0])) as PackedScene).instantiate()
			viewport.add_child(npc)
			npc.position = Vector2(90.0 + column * 180.0, 150.0 + row * 158.0)
			npc.set_process(false)
			var action := StringName(actions[column])
			if row == 0:
				npc.get_node("Visual").call("play_animation", action, true)
				npc.get_node("Visual").call("set_frame_for_review", 3)
			else:
				npc.get_node("Visual").set("ambient_enabled", false)
				npc.get_node("Visual").call("play_state", action)
				npc.get_node("Visual").call("advance_animation", 2.0)
	await process_frame
	await process_frame
	await process_frame
	var output_path := capture_directory.path_join("town_character_action_state_sheet.png")
	_expect(viewport.get_texture().get_image().save_png(output_path) == OK, "Character action state sheet must save.")
	viewport.queue_free()
	await process_frame


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town NPC animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
