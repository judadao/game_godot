extends SceneTree

const EFFECT_SCENE := preload("res://scenes/combat/vfx/NamedSkillVFX.tscn")
const ROUTER_SCRIPT := preload("res://scripts/vfx/series_impact_vfx_router.gd")

const FIRE_PILLAR := "res://assets/generated/vfx/skill_materials/components/base/fire__fire_pillar.png"
const STONE_ORBIT := "res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_orbit.png"
const STONE_LANCE := "res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_lance.png"
const STONE_LANCE_SHADER := "res://shaders/vfx/stone_lance_core_preserve.gdshader"
const TIDAL_CURL := "res://assets/generated/vfx/skill_materials/components/base/water_flow__tidal_curl.png"
const CHAIN_BOLT := "res://assets/generated/vfx/skill_materials/components/base/lightning__chain_bolt.png"
const SKY_IMPACT := "res://assets/generated/vfx/skill_materials/components/base/lightning__sky_impact.png"
const VOID_RING := "res://assets/generated/vfx/skill_materials/components/base/black_hole__void_ring.png"
const DRAGON_HEAD := "res://assets/generated/vfx/skill_materials/components/base/dragon_breath__dragon_head.png"
const BREATH_BEAM := "res://assets/generated/vfx/skill_materials/components/base/dragon_breath__breath_beam.png"


class LightningFixture:
	extends Node
	signal final_strike(target: Node, target_position: Vector2)
	signal shot_fired(drone_index: int, origin: Vector2, target: Node, target_position: Vector2)


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var thorn := await _series_state("thorn", 3, "get_thorn_bloom_vfx_state")
	_expect(float(thorn.get("terminal_flower_scale", 0.0)) >= 0.125, "Thorn terminal flowers must be visibly larger than the previous 0.098 master scale.")

	var fire := await _series_state("fire", 3, "get_fire_pillar_vfx_state")
	_expect(String(fire.get("renderer", "")) == "continuous_fire_pillar_sprite", "Fire needs a dedicated continuous raster pillar renderer.")
	_expect(String(fire.get("pillar_texture", "")) == FIRE_PILLAR, "Fire pillars must use the supplied fire_pillar raster.")
	_expect(int(fire.get("segments_per_pillar", 0)) >= 3, "Each fire eruption must extend to multiple logical pillar segments.")
	_expect(bool(fire.get("continuous_nine_patch_body", false)), "Fire must tile one continuous pillar body without repeating the explosion base or crown.")
	_expect(int(fire.get("line_layer_count", -1)) == 0, "Fire must not retain the old low-quality line scaffold.")

	var stone := await _series_state("dr_stone", 3, "get_dr_stone_vfx_state")
	_expect(String(stone.get("drone_texture", "")) == STONE_ORBIT, "DR. Stone drones must use stone_orbit.")
	_expect(String(stone.get("projectile_texture", "")) == STONE_LANCE, "DR. Stone auto-fire must use stone_lance.")
	_expect(String(stone.get("projectile_material_shader", "")) == STONE_LANCE_SHADER, "Stone lances must use their dark-core-preserving material.")
	_expect(int(stone.get("projectile_sprite_count", 0)) >= int(stone.get("drone_count", 1)), "Every drone needs a reusable stone-lance shot sprite.")
	_expect(int(stone.get("visible_line_count", -1)) == 0, "DR. Stone must remove the old rune and shot Line2D shapes.")

	var water := await _series_state("water_flow", 3, "get_tidal_push_vfx_state")
	_expect(String(water.get("renderer", "")) == "outward_tidal_curl_sprite", "Water Flow needs a dedicated outward wave renderer.")
	_expect(String(water.get("wave_texture", "")) == TIDAL_CURL, "Water Flow must use tidal_curl.")
	_expect((water.get("directions", []) as Array) == [-1, 1], "Water waves must move outward on both sides of the caster.")
	_expect(float(water.get("end_wave_scale", 0.0)) > float(water.get("start_wave_scale", 0.0)), "Master tidal curls must grow while travelling outward.")
	_expect(int(water.get("line_layer_count", -1)) == 0, "Water Flow must remove the old arc-line scaffold.")

	var black_hole := await _series_state("black_hole", 3, "get_black_hole_vfx_state")
	_expect(String(black_hole.get("main_texture", "")) == VOID_RING, "Black Hole must use void_ring as its sole main body.")
	_expect(int(black_hole.get("main_sprite_count", 0)) == 1, "Black Hole must have one readable raster main body.")
	_expect(int(black_hole.get("visible_line_count", -1)) == 0, "Black Hole must remove generated accretion Line2D clutter.")
	_expect(bool(black_hole.get("rotates_and_pulses", false)), "Black Hole must rotate and scale in/out.")

	var dragon := await _series_state("dragon_breath", 3, "get_dragon_breath_vfx_state")
	_expect(String(dragon.get("renderer", "")) == "sweeping_dragon_head_beam", "Dragon Breath needs a dedicated head-and-beam renderer.")
	_expect(String(dragon.get("head_texture", "")) == DRAGON_HEAD, "Dragon Breath must use the supplied dragon head.")
	_expect(String(dragon.get("beam_texture", "")) == BREATH_BEAM, "Dragon Breath must tile the supplied breath beam.")
	_expect(int(dragon.get("head_count", 0)) == 22, "Master Dragon Breath must retain two side heads plus twenty upper heads.")
	_expect(int(dragon.get("beam_tile_count", 0)) > int(dragon.get("head_count", 0)), "Breath jets must be visibly tiled instead of one stretched plate.")
	_expect(float(dragon.get("head_scale", 0.0)) >= 0.20, "Dragon heads must be larger and readable.")
	_expect(float(dragon.get("side_head_y_sweep_span", 0.0)) >= 120.0, "Side dragon heads must sweep vertically along the Y axis.")
	_expect(int(dragon.get("line_layer_count", -1)) == 0, "Dragon Breath must remove the old arc-line scaffold.")

	var visual_root := Node2D.new()
	root.add_child(visual_root)
	var router := ROUTER_SCRIPT.new()
	root.add_child(router)
	var fixture := LightningFixture.new()
	root.add_child(fixture)
	_expect(bool(router.call("bind_controller", "lightning", fixture, visual_root, [])), "Lightning final strike must bind through the gameplay event router.")
	fixture.final_strike.emit(null, Vector2(240.0, 180.0))
	await process_frame
	var strike := visual_root.get_node_or_null("LightningSkyStrikeVFX")
	_expect(strike != null, "Final Lightning must create the dedicated raster sky-strike sequence.")
	if strike != null:
		_expect(String(strike.get_meta("bolt_texture", "")) == CHAIN_BOLT, "Sky strike must rotate chain_bolt into a vertical descent.")
		_expect(String(strike.get_meta("impact_texture", "")) == SKY_IMPACT, "Sky strike must finish with sky_impact on the ground.")
		_expect(int(strike.get_meta("afterimage_count", 0)) >= 3, "Sky strike needs downward afterimages.")
		_expect(bool(strike.get_meta("vertical_descent", false)), "Sky strike bolt motion must be vertical.")
		_expect(bool(strike.get_meta("ground_anchored_impact", false)), "Sky impact must be anchored at the gameplay target position.")
	var stone_root := Node2D.new()
	root.add_child(stone_root)
	var stone_fixture := LightningFixture.new()
	root.add_child(stone_fixture)
	_expect(bool(router.call("bind_controller", "dr_stone", stone_fixture, stone_root, [])), "DR. Stone auto-fire must bind through its gameplay shot event.")
	stone_fixture.shot_fired.emit(0, Vector2(40.0, 80.0), null, Vector2(260.0, 110.0))
	await process_frame
	var routed_lance := stone_root.get_node_or_null("StoneLanceVFX")
	_expect(routed_lance != null, "Every gameplay drone shot must create the dedicated stone-lance sprite.")
	if routed_lance != null:
		_expect(String(routed_lance.get_meta("projectile_texture", "")) == STONE_LANCE, "Gameplay drone shots must retain the supplied stone_lance source.")
	_finish()


func _series_state(series_id: String, tier: int, getter: String) -> Dictionary:
	var effect := EFFECT_SCENE.instantiate()
	root.add_child(effect)
	effect.call("play_series", series_id, tier, 1, false, 1.0)
	effect.call("debug_set_progress", 0.62)
	var state := effect.call(getter) as Dictionary
	effect.queue_free()
	await process_frame
	return state


func _finish() -> void:
	if _failures == 0:
		print("PASS: requested skill series use their authored raster motion contracts")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
