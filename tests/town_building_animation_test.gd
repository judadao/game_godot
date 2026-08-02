extends SceneTree

const BACKDROP_SCENE := "res://scenes/maps/town/components/TownBackdrop.tscn"
const BUILDING_ANIMATION_SCENE := (
	"res://scenes/maps/town/components/TownBuildingAnimation.tscn"
)
const CUSTOM_WINDOW_SCENES := {
	"TownHallUpperLeft": "res://scenes/maps/town/components/TownArchedWindowGlow.tscn",
	"TownHallUpperRight": "res://scenes/maps/town/components/TownArchedWindowGlow.tscn",
	"TownHallLowerLeft": "res://scenes/maps/town/components/TownTallArchedWindowGlow.tscn",
	"TownHallLowerRight": "res://scenes/maps/town/components/TownTallArchedWindowGlow.tscn",
	"SwordSoulUpper": "res://scenes/maps/town/components/TownRadialWindowGlow.tscn",
}

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var animation_resource := load(BUILDING_ANIMATION_SCENE) as PackedScene
	_expect(animation_resource != null, "Town building animation scene must exist.")
	if animation_resource == null:
		_finish()
		return

	var animation := animation_resource.instantiate() as Node2D
	root.add_child(animation)
	await process_frame
	_expect(
		animation.has_method("get_building_animation_contract"),
		"Town building animation must expose its visual-only contract."
	)
	var contract: Dictionary = animation.call("get_building_animation_contract")
	_expect(int(contract.get("window_groups", 0)) == 11, "All 11 visible window groups must animate.")
	_expect(int(contract.get("cloth_groups", 0)) == 7, "All seven visible cloth groups must animate.")
	_expect(int(contract.get("metal_glints", 0)) == 4, "Four authored metal glints must remain sparse.")
	_expect(bool(contract.get("forge_warmth", false)), "Player forge must own animated warmth.")
	_expect(bool(contract.get("clock_ticks", false)), "Town Hall clock must advance in pixel steps.")
	_expect(
		bool(contract.get("blueprint_gear_static", false)),
		"Blueprint shop gear must remain visible without a rotation animation."
	)
	_expect(bool(contract.get("collision_owned", true)) == false, "Building animation must stay visual-only.")

	_assert_windows(animation.get_node_or_null("WindowLights") as Node2D)
	_assert_forge(animation.get_node_or_null("ForgeWarmth") as Node2D)
	_assert_cloth(animation.get_node_or_null("ClothMotions") as Node2D)
	_assert_clock(animation.get_node_or_null("ClockMechanism") as Node2D)
	_assert_mechanical_details(animation.get_node_or_null("MechanicalDetails") as Node2D)
	_assert_glints(animation.get_node_or_null("MetalGlints") as Node2D)
	_expect(not _contains_gameplay_node(animation), "Building animation must not own gameplay nodes.")

	var backdrop_resource := load(BACKDROP_SCENE) as PackedScene
	_expect(backdrop_resource != null, "Town backdrop must remain loadable.")
	if backdrop_resource != null:
		var backdrop := backdrop_resource.instantiate()
		root.add_child(backdrop)
		await process_frame
		_expect(
			backdrop.get_node_or_null("BuildingAnimation") != null,
			"TownBackdrop must instance the authoritative building animation component."
		)
		backdrop.queue_free()

	animation.queue_free()
	await process_frame
	_finish()


func _assert_windows(windows: Node2D) -> void:
	_expect(windows != null, "WindowLights container must be editor-authored.")
	if windows == null:
		return
	_expect(windows.get_child_count() == 11, "WindowLights must contain exactly 11 visible window groups.")
	var phases: Dictionary = {}
	for child in windows.get_children():
		_expect(child is Node2D, "%s must be a Node2D window group." % child.name)
		if not child is Node2D:
			continue
		var period := float(child.get_meta("period", 0.0))
		var phase := float(child.get_meta("phase", -1.0))
		_expect(period >= 2.3 and period <= 4.8, "%s must flicker slowly." % child.name)
		_expect(phase >= 0.0, "%s must have an authored phase." % child.name)
		phases[phase] = true
		_expect(child.get_child_count() >= 4, "%s must mask separate glass panes." % child.name)
		for pane in child.get_children():
			_expect(pane is Polygon2D, "%s panes must be Polygon2D masks." % child.name)
	for window_name in CUSTOM_WINDOW_SCENES:
		var custom_window := windows.get_node_or_null(window_name)
		_expect(custom_window != null, "%s custom window must exist." % window_name)
		if custom_window != null:
			_expect(
				custom_window.scene_file_path == CUSTOM_WINDOW_SCENES[window_name],
				"%s must use its authored pane geometry." % window_name
			)
	_expect(phases.size() >= 10, "Window phases must be distributed rather than synchronized.")


func _assert_forge(forge: Node2D) -> void:
	_expect(forge != null, "ForgeWarmth container must be editor-authored.")
	if forge == null:
		return
	var hearth := forge.get_node_or_null("HearthCore") as AnimatedSprite2D
	_expect(hearth != null, "Forge needs a hand-drawn AnimatedSprite2D hearth core.")
	if hearth != null:
		_expect(hearth.sprite_frames.get_frame_count(&"hearth") == 8, "Forge hearth must retain eight hand-drawn frames.")
	_expect(forge.get_node_or_null("HearthEmbers") is Polygon2D, "Forge needs authored embers.")
	_expect(forge.get_node_or_null("WallBounce") is Polygon2D, "Forge needs local warm wall bounce.")
	_expect(forge.z_index < 0, "Forge warmth must remain behind NPCs and interactions.")


func _assert_cloth(cloth: Node2D) -> void:
	_expect(cloth != null, "ClothMotions container must be editor-authored.")
	if cloth == null:
		return
	_expect(cloth.get_child_count() == 7, "ClothMotions must contain all seven visible cloth regions.")
	for pivot in cloth.get_children():
		_expect(pivot is Node2D, "%s must be an authored cloth pivot." % pivot.name)
		if not pivot is Node2D:
			continue
		_expect(
			float(pivot.get_meta("period", 0.0)) >= 2.6,
			"%s must move gently rather than flap rapidly." % pivot.name
		)
		_expect(
			float(pivot.get_meta("max_offset", 99.0)) <= 2.0,
			"%s must stay within a two-pixel motion budget." % pivot.name
		)
		_expect(pivot.get_child_count() == 1, "%s must own one cropped cloth sprite." % pivot.name)
		if pivot.get_child_count() == 1:
			var sprite := pivot.get_child(0) as Sprite2D
			_expect(sprite != null, "%s must animate a Sprite2D crop." % pivot.name)
			if sprite != null:
				_expect(sprite.texture is AtlasTexture, "%s must reuse exact building pixels." % pivot.name)
				_expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s must keep nearest filtering." % pivot.name)


func _assert_clock(clock: Node2D) -> void:
	_expect(clock != null, "ClockMechanism must be editor-authored.")
	if clock == null:
		return
	_expect(clock.get_node_or_null("Face") is Polygon2D, "Clock must cover the baked static hands.")
	_expect(clock.get_node_or_null("HourHand") is Line2D, "Clock must expose an hour hand.")
	_expect(clock.get_node_or_null("MinuteHand") is Line2D, "Clock must expose a minute hand.")
	_expect(clock.get_node_or_null("SecondHand") is Line2D, "Clock must expose a discrete second hand.")
	_expect(float(clock.get_meta("step_seconds", 0.0)) >= 1.0, "Clock must advance with discrete readable ticks.")


func _assert_mechanical_details(details: Node2D) -> void:
	_expect(details != null, "MechanicalDetails must be editor-authored.")
	if details == null:
		return
	var gear := details.get_node_or_null("BlueprintGear") as Node2D
	_expect(gear != null, "Blueprint shop must retain a static gear overlay.")
	if gear == null:
		return
	_expect(
		not gear.has_meta("step_seconds"),
		"Static blueprint gear must not retain rotation timing metadata."
	)
	var hand_drawn := gear.get_node_or_null("HandDrawnGear") as Sprite2D
	_expect(hand_drawn != null, "Blueprint gear must use a static hand-drawn Sprite2D.")
	if hand_drawn != null:
		_expect(
			hand_drawn.texture != null
			and hand_drawn.texture.resource_path.ends_with(
				"/blueprint_gear_handdrawn/frame_00.png"
			),
			"Blueprint gear must display the authored neutral hand-drawn frame."
		)
		_expect(
			hand_drawn.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Blueprint gear must keep nearest filtering."
		)
	_expect(not _contains_vector_art(gear), "Blueprint gear must not fall back to vector line art.")


func _assert_glints(glints: Node2D) -> void:
	_expect(glints != null, "MetalGlints container must be editor-authored.")
	if glints == null:
		return
	_expect(glints.get_child_count() == 4, "Metal glints must stay sparse and authored.")
	var sword_crest := glints.get_node_or_null("SwordCrestGlint") as Node2D
	var sword_reflection := (
		sword_crest.get_node_or_null("HandDrawnReflection") as AnimatedSprite2D
		if sword_crest != null
		else null
	)
	_expect(
		sword_reflection != null,
		"Sword shop crest needs a hand-drawn reflection AnimatedSprite2D."
	)
	if sword_reflection != null:
		_expect(
			sword_reflection.sprite_frames.get_frame_count(&"glint") == 6,
			"Sword reflection must retain all six hand-drawn frames."
		)
		_expect(
			sword_reflection.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Sword reflection must keep nearest filtering."
		)
	for glint in glints.get_children():
		_expect(float(glint.get_meta("interval", 0.0)) >= 3.6, "%s must not sparkle constantly." % glint.name)
		_expect(float(glint.get_meta("duration", 1.0)) <= 0.7, "%s glint must be a brief event." % glint.name)


func _contains_gameplay_node(node: Node) -> bool:
	if node is CollisionObject2D or node is CollisionShape2D or node is NavigationRegion2D:
		return true
	for child in node.get_children():
		if _contains_gameplay_node(child):
			return true
	return false


func _contains_vector_art(node: Node) -> bool:
	if node is Line2D or node is Polygon2D:
		return true
	for child in node.get_children():
		if _contains_vector_art(child):
			return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town building animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
