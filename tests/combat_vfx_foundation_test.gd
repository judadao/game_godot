extends SceneTree

const REQUIRED_LAYERS := [
	"dark_slash_trail",
	"bright_slash_core",
	"impact_flash",
	"impact_flare",
	"impact_shockwave",
	"impact_sparks",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/combat/vfx/NamedSkillVFX.tscn") as PackedScene
	var effect := packed.instantiate() if packed != null else null
	_expect(effect != null, "Combat VFX foundation requires NamedSkillVFX.")
	if effect == null:
		quit(1)
		return
	root.add_child(effect)
	await process_frame
	effect.call("play_series", "sword_rain", 2, 1, true)
	var slash_state := effect.call("get_series_debug_state") as Dictionary
	var slash_layers := slash_state.get("foundation_layers", []) as Array
	for layer_id in REQUIRED_LAYERS:
		_expect(slash_layers.has(layer_id), "Series combat VFX must include %s from the tutorial foundation." % layer_id)
	effect.call("debug_set_progress", 0.70)
	var impact_state := effect.call("get_vfx_foundation_debug_state") as Dictionary
	_expect(float(impact_state.get("impact_energy", 0.0)) > 0.0, "Impact layers must peak near the actual hit beat.")
	effect.call("play_series", "fire", 3, 1, true)
	var fire_state := effect.call("get_vfx_foundation_debug_state") as Dictionary
	var fire_layers := fire_state.get("layers", []) as Array
	for layer_id in ["flame_body", "flame_dissolve", "fire_smoke", "floating_embers", "explosion_fire", "explosion_smoke"]:
		_expect(fire_layers.has(layer_id), "Fire series must include the reusable %s layer." % layer_id)
	_expect(String(fire_state.get("attachment_mode", "")) == "object_outline", "Series fire must support attachment around one main object.")
	_expect(bool(fire_state.get("slash_scroll_shader", false)) and bool(fire_state.get("flame_dissolve_shader", false)), "Slash scrolling and flame dissolve must be real reusable shader passes.")
	_expect(int(effect.call("get_active_layer_count")) > int(slash_state.get("object_count", 0)), "Foundation VFX must add real render layers, not debug metadata only.")
	effect.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: tutorial-derived fire, slash, explosion, and impact layers compose combat VFX")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
