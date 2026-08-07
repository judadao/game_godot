extends SceneTree

const EXPECTED_SERIES := [
	"sword_rain", "moon_wheel", "feather", "ancient_wood", "giant_stone",
	"great_shield", "fire", "lightning", "water_flow", "plant_attack",
	"dragon_breath", "dawn_vitality", "shared_branch_vitality",
]
const REQUIRED_GRAMMAR := [
	"core", "trail", "arc", "beam", "bolt", "ring", "burst", "impact",
	"projectile", "orbit", "rain", "aura", "ground_zone", "afterimage",
	"distortion",
]
const BLESSING_ELEMENTS := [
	"fire", "lightning", "water", "poison", "ice", "wind", "light", "dark",
]
const REQUIRED_DEMOS := [
	"slash_vfx_demo", "fireball_vfx_demo", "lightning_strike_vfx_demo",
	"area_burst_vfx_demo", "moon_wheel_vfx_demo",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script := load("res://scripts/vfx/skill_vfx_recipe_catalog.gd") as Script
	var composer_scene := load("res://scenes/vfx/SkillVFXComposer2D.tscn") as PackedScene
	_expect(catalog_script != null, "Skill VFX Grammar needs one recipe catalog authority.")
	_expect(composer_scene != null, "Skill VFX Grammar needs one reusable composer scene.")
	if catalog_script == null or composer_scene == null:
		_finish()
		return

	var catalog := catalog_script.new() as RefCounted
	_expect(bool(catalog.call("load_catalog")), "Skill VFX recipe catalog must validate and load.")
	var recipe_ids := catalog.call("get_recipe_ids") as Array
	_expect(recipe_ids == EXPECTED_SERIES, "Every current series needs exactly one ordered VFX recipe.")
	_expect((catalog.call("get_grammar_ids") as Array) == REQUIRED_GRAMMAR, "The reusable Skill VFX Grammar must expose all 15 primitive roles.")
	for series_id in EXPECTED_SERIES:
		var recipe := catalog.call("get_recipe", series_id) as Dictionary
		var grammar := recipe.get("grammar", []) as Array
		_expect(grammar.size() >= 5, "%s must compose at least five grammar primitives." % series_id)
		_expect(grammar.has("core") and grammar.has("impact"), "%s must retain a readable core and contact layer." % series_id)
		_expect(not String(recipe.get("asset_path", "")).is_empty(), "%s must preserve its existing main-object asset as Core." % series_id)
		_expect(ResourceLoader.exists(String(recipe.get("asset_path", "")), "Texture2D"), "%s Core asset must remain loadable." % series_id)

	var composer := composer_scene.instantiate() as Node2D
	root.add_child(composer)
	await process_frame
	_expect(composer.has_method("configure"), "Skill VFX Composer must expose configure().")
	_expect(composer.has_method("set_progress"), "Skill VFX Composer must expose deterministic timeline control.")
	_expect(composer.has_method("get_debug_state"), "Skill VFX Composer must expose visual diagnostics.")
	var fire_recipe := catalog.call("get_recipe", "fire") as Dictionary
	var overlays: Array = []
	for element in BLESSING_ELEMENTS:
		overlays.append({"id": "%s_test" % element, "element": element, "level": 2})
	_expect(bool(composer.call("configure", fire_recipe, 3, overlays)), "Composer must accept one recipe plus stacked Blessing mutations.")
	composer.call("set_progress", 0.62, Vector2.ZERO, Vector2(260.0, 0.0), [])
	var state := composer.call("get_debug_state") as Dictionary
	_expect(String(state.get("presentation_mode", "")) == "procedural_vfx_recipe", "Current skills must identify procedural recipe playback, not GIF playback.")
	_expect((state.get("grammar", []) as Array).size() >= 5, "Runtime recipe must retain its authored primitive grammar.")
	_expect(int(state.get("real_visual_layer_count", 0)) >= 5, "Composer grammar must create real render layers, not metadata only.")
	_expect(int(state.get("mutation_count", 0)) == BLESSING_ELEMENTS.size(), "Every owned Blessing must contribute one stackable visual mutation.")
	_expect(int(state.get("visual_count_bonus", 0)) > 0, "Blessing mutations must be able to add visible copies.")
	_expect(float(state.get("trajectory_variation", 0.0)) > 0.0, "Blessing mutations must change the visible path geometry.")
	_expect(not String(state.get("impact_primitive", "")).is_empty(), "Blessing mutations must select a concrete impact primitive.")
	_expect(not (state.get("resolved_palette", []) as Array).is_empty(), "Blessing mutation stacking must resolve a final runtime palette.")
	_expect(bool(state.get("uses_existing_core_asset", false)), "Recipe VFX must reuse current skill art as its Core instead of deleting it.")
	_expect(bool(state.get("legacy_fallback_retained", false)), "Current series presentation must remain available as a fallback during migration.")
	composer.queue_free()
	await process_frame
	for demo_id in REQUIRED_DEMOS:
		var demo_path := "res://scenes/vfx/demos/%s.tscn" % demo_id
		var demo_scene := load(demo_path) as PackedScene
		_expect(demo_scene != null, "%s must exist as a standalone pure-VFX inspection scene." % demo_id)
		if demo_scene == null:
			continue
		var demo := demo_scene.instantiate()
		root.add_child(demo)
		await process_frame
		_expect(demo.find_children("*", "AnimatedSprite2D", true, false).is_empty(), "%s must compose primitives and trajectories instead of a frame animation." % demo_id)
		_expect(not demo.find_children("*", "SkillVFXComposer2D", true, false).is_empty(), "%s must exercise the production Skill VFX Composer." % demo_id)
		demo.queue_free()
		await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: 13 current skill series compose procedural VFX recipes with Blessing mutations")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
