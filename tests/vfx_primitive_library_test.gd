extends SceneTree

const REQUIRED_EFFECTS := [
	"fire/fire_loop",
	"fire/fire_burst",
	"fire/fire_trail",
	"lightning/lightning_bolt",
	"lightning/electric_arc",
	"lightning/lightning_impact",
	"water/water_stream",
	"water/water_splash",
	"water/wave_arc",
	"poison/poison_cloud",
	"poison/poison_bubble",
	"poison/poison_splash",
	"ice/ice_mist",
	"ice/ice_shard",
	"ice/ice_shatter",
	"wind/wind_stream",
	"wind/wind_slash",
	"wind/wind_burst",
]
const REQUIRED_PARAMETERS := [
	"primary_color",
	"secondary_color",
	"intensity",
	"effect_lifetime",
	"effect_scale",
	"speed",
	"direction",
	"particle_amount",
	"noise_amount",
	"glow_strength",
]
const REQUIRED_SHADERS := [
	"res://shaders/vfx/pixel_fire.gdshader",
	"res://shaders/vfx/fire_distortion.gdshader",
	"res://shaders/vfx/electric_arc.gdshader",
	"res://shaders/vfx/water_body.gdshader",
	"res://shaders/vfx/dissolve.gdshader",
	"res://shaders/vfx/poison_corrosion.gdshader",
	"res://shaders/vfx/corrosion_advanced.gdshader",
	"res://shaders/vfx/custom_particle_motion.gdshader",
]
const MAX_PARTICLE_BUDGET := 160

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_shared_primitives()
	_test_element_library()
	_test_shader_library()
	_test_documentation()
	if _failures == 0:
		print("PASS: reusable layered VFX primitive library contract")
	quit(1 if _failures > 0 else 0)


func _test_shared_primitives() -> void:
	var particle_scene := load("res://scenes/vfx/primitives/ParticleBurst2D.tscn") as PackedScene
	_expect(particle_scene != null, "ParticleBurst2D reusable primitive scene must load.")
	_expect(
		ResourceLoader.exists("res://scenes/vfx/demos/vfx_particle_test.tscn", "PackedScene"),
		"Continuous and one-shot particle behavior needs a standalone test scene."
	)
	_expect(
		ResourceLoader.exists("res://scenes/vfx/demos/custom_particle_shader_demo.tscn", "PackedScene"),
		"Custom particle shader needs a standalone demo scene."
	)
	if particle_scene != null:
		var burst := particle_scene.instantiate() as GPUParticles2D
		root.add_child(burst)
		await process_frame
		_expect(burst.one_shot and not burst.emitting, "ParticleBurst2D must idle as a reusable one-shot emitter.")
		_expect(burst.process_material is ParticleProcessMaterial, "ParticleBurst2D must configure ParticleProcessMaterial movement.")
		_expect(burst.visibility_rect.size.x > 0.0, "ParticleBurst2D must configure bounded visibility.")
		burst.call("burst")
		_expect(burst.emitting, "ParticleBurst2D.burst() must restart emission.")
		burst.queue_free()
		await process_frame
	var lightning_script := load("res://scripts/vfx/lightning_generator_2d.gd") as Script
	_expect(lightning_script != null, "Procedural LightningGenerator2D script must load.")
	if lightning_script != null:
		var lightning := lightning_script.new() as Node2D
		root.add_child(lightning)
		lightning.call("set_endpoints", Vector2.ZERO, Vector2(240.0, 0.0))
		var bolt_points := lightning.call("get_main_points") as PackedVector2Array
		_expect(bolt_points.size() >= 17, "LightningGenerator2D must subdivide an A-to-B bolt into readable segments.")
		_expect(bolt_points[0].is_equal_approx(Vector2.ZERO) and bolt_points[-1].is_equal_approx(Vector2(240.0, 0.0)), "Lightning subdivision must preserve exact endpoints.")
		lightning.queue_free()
		await process_frame
	var trail_script := load("res://scripts/vfx/trail_history_2d.gd") as Script
	_expect(trail_script != null, "Reusable history-based VFX trail script must load.")


func _test_element_library() -> void:
	for relative_id in REQUIRED_EFFECTS:
		var effect_name: String = relative_id.get_file()
		var scene_path := "res://scenes/vfx/primitives/%s.tscn" % relative_id
		var demo_path := "res://scenes/vfx/demos/%s_demo.tscn" % effect_name
		var packed := load(scene_path) as PackedScene
		var demo_packed := load(demo_path) as PackedScene
		_expect(packed != null, "%s reusable primitive scene must load." % scene_path)
		_expect(demo_packed != null, "%s needs a loadable standalone demo scene." % effect_name)
		if packed == null:
			continue
		var effect := packed.instantiate() as Node2D
		_expect(effect != null, "%s root must be Node2D." % effect_name)
		if effect == null:
			continue
		root.add_child(effect)
		for property_name in REQUIRED_PARAMETERS:
			_expect(_has_property(effect, property_name), "%s must expose %s." % [effect_name, property_name])
		_expect(effect.has_method("play") and effect.has_method("stop"), "%s must expose reusable lifecycle methods." % effect_name)
		_expect(effect.has_method("get_layer_names"), "%s must expose its visual layer contract." % effect_name)
		_expect(effect.has_method("get_particle_budget"), "%s must expose its particle budget." % effect_name)
		_expect(effect.has_method("get_visual_bounds"), "%s must expose bounded culling dimensions." % effect_name)
		await process_frame
		if effect.has_method("get_layer_names"):
			var layer_names := effect.call("get_layer_names") as Array
			_expect(layer_names.size() >= 4, "%s must compose at least four independent visual layers." % effect_name)
			_expect(_all_layers_exist(effect, layer_names), "%s declared visual layers must exist as nodes." % effect_name)
		if effect.has_method("get_particle_budget"):
			_expect(int(effect.call("get_particle_budget")) <= MAX_PARTICLE_BUDGET, "%s exceeds the reusable particle budget." % effect_name)
		if effect.has_method("get_visual_bounds"):
			var bounds := effect.call("get_visual_bounds") as Rect2
			_expect(bounds.size.x > 0.0 and bounds.size.y > 0.0, "%s must define non-empty visual bounds." % effect_name)
		if effect_name == "fire_loop":
			_expect((effect.get_node("FireCore") as Line2D).material is ShaderMaterial, "Fire core must use the learned pixel-fire shader technique.")
			_expect((effect.get_node("OuterFlame") as Line2D).material is ShaderMaterial, "Outer flame must independently expose distortion.")
		elif effect_name == "electric_arc":
			_expect((effect.get_node("MainBolt") as Line2D).material is ShaderMaterial, "Electric arc must use a transparent procedural arc shader.")
		elif effect_name == "water_stream":
			_expect((effect.get_node("MainBody") as Line2D).material is ShaderMaterial, "Water body must use pixel-quantized wave distortion.")
		elif effect_name == "poison_cloud":
			_expect((effect.get_node("Corrosion") as Line2D).material is ShaderMaterial, "Poison corrosion must use an independent dissolve-mask material.")
		_expect(not effect.is_in_group("Gameplay"), "%s must remain presentation-only." % effect_name)
		effect.queue_free()
		await process_frame


func _test_shader_library() -> void:
	for shader_path in REQUIRED_SHADERS:
		var shader := load(shader_path) as Shader
		_expect(shader != null, "%s must load as a Godot 4 shader." % shader_path)
	var custom_particle := load("res://shaders/vfx/custom_particle_motion.gdshader") as Shader
	if custom_particle != null:
		_expect(custom_particle.code.contains("shader_type particles"), "Custom particle motion demo must use a real particle shader.")
	_expect(load("res://scenes/vfx/demos/VFXLibraryDemo.tscn") is PackedScene, "The complete primitive library needs one visual inspection scene.")
	_expect(load("res://scenes/vfx/demos/vfx_particle_test.tscn") is PackedScene, "Continuous/one-shot particle test scene must parse.")
	_expect(load("res://scenes/vfx/demos/custom_particle_shader_demo.tscn") is PackedScene, "Custom particle shader demo scene must parse.")


func _test_documentation() -> void:
	_expect(FileAccess.file_exists("res://docs/vfx/shader_notes.md"), "VFX study must record Godot shader fundamentals.")
	_expect(FileAccess.file_exists("res://docs/vfx/vfx_cookbook.md"), "VFX study must record reusable element techniques and source links.")


func _all_layers_exist(effect: Node, layer_names: Array) -> bool:
	for layer_name in layer_names:
		if effect.get_node_or_null(NodePath(String(layer_name))) == null:
			return false
	return true


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
