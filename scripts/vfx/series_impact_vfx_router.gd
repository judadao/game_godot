class_name SeriesImpactVFXRouter
extends Node

const RASTER_EVENT_VFX := preload("res://scripts/vfx/series_raster_event_vfx_2d.gd")

const PRIMITIVE_SCENES := {
	&"fire_burst": preload("res://scenes/vfx/primitives/fire/fire_burst.tscn"),
	&"lightning_bolt": preload("res://scenes/vfx/primitives/lightning/lightning_bolt.tscn"),
	&"lightning_impact": preload("res://scenes/vfx/primitives/lightning/lightning_impact.tscn"),
	&"water_splash": preload("res://scenes/vfx/primitives/water/water_splash.tscn"),
	&"wave_arc": preload("res://scenes/vfx/primitives/water/wave_arc.tscn"),
	&"poison_splash": preload("res://scenes/vfx/primitives/poison/poison_splash.tscn"),
	&"ice_shatter": preload("res://scenes/vfx/primitives/ice/ice_shatter.tscn"),
	&"wind_slash": preload("res://scenes/vfx/primitives/wind/wind_slash.tscn"),
	&"wind_burst": preload("res://scenes/vfx/primitives/wind/wind_burst.tscn"),
}

const SERIES_PALETTES := {
	&"moon_wheel": [Color("fff8c9"), Color("78d9ff")],
	&"feather": [Color("fffce7"), Color("f5cc67")],
	&"thorn": [Color("efff9c"), Color("67b84c")],
	&"dr_stone": [Color("fff0bd"), Color("9d8665")],
	&"black_hole": [Color("ead7ff"), Color("6a36bd")],
	&"fire": [Color("fff3a0"), Color("ff5a19")],
	&"lightning": [Color("f8fdff"), Color("65cfff")],
	&"water_flow": [Color("e9ffff"), Color("38bfe2")],
	&"arcane_swamp": [Color("dfff79"), Color("71369e")],
	&"dragon_breath": [Color("fff0a0"), Color("e53a16")],
	&"dawn_vitality": [Color("f0ffd2"), Color("55d989")],
	&"shared_branch_vitality": [Color("fff0c7"), Color("b26dff")],
}

var _spawn_count := 0
var _effect_counts: Dictionary = {}


func bind_controller(
	series_id: String,
	controller: Node,
	visual_parent: Node,
	blessing_overlays: Array = []
) -> bool:
	if controller == null or visual_parent == null:
		return false
	var bound := false
	match series_id:
		"moon_wheel":
			bound = _connect_if_present(controller, &"impact", Callable(self, "_on_point_hit").bind(series_id, &"wind_burst", visual_parent, blessing_overlays)) or bound
		"fire":
			bound = _connect_if_present(controller, &"pillar_erupted", Callable(self, "_on_indexed_point").bind(series_id, &"fire_burst", visual_parent, blessing_overlays)) or bound
		"lightning":
			bound = _connect_if_present(controller, &"chain_hit", Callable(self, "_on_lightning_chain").bind(visual_parent, blessing_overlays)) or bound
			bound = _connect_if_present(controller, &"final_strike", Callable(self, "_on_lightning_final").bind(visual_parent, blessing_overlays)) or bound
		"water_flow":
			bound = _connect_if_present(controller, &"wave_pulse", Callable(self, "_on_point_hit").bind(series_id, &"water_splash", visual_parent, blessing_overlays)) or bound
		"dragon_breath":
			bound = _connect_if_present(controller, &"rain_emitter_fired", Callable(self, "_on_indexed_point").bind(series_id, &"fire_burst", visual_parent, blessing_overlays)) or bound
			bound = _connect_if_present(controller, &"impact", Callable(self, "_on_point_hit").bind(series_id, &"fire_burst", visual_parent, blessing_overlays)) or bound
		"black_hole":
			bound = _connect_if_present(controller, &"detonated", Callable(self, "_on_detonated").bind(series_id, &"wind_burst", visual_parent, blessing_overlays)) or bound
		"thorn":
			bound = _connect_if_present(controller, &"volley_fired", Callable(self, "_on_volley").bind(series_id, &"poison_splash", visual_parent, blessing_overlays)) or bound
		"arcane_swamp":
			bound = _connect_if_present(controller, &"pulse_hit", Callable(self, "_on_point_hit").bind(series_id, &"poison_splash", visual_parent, blessing_overlays)) or bound
		"dr_stone":
			bound = _connect_if_present(controller, &"shot_fired", Callable(self, "_on_drone_shot").bind(visual_parent, blessing_overlays)) or bound
			bound = _connect_if_present(controller, &"drone_crashed", Callable(self, "_on_indexed_point").bind(series_id, &"wind_burst", visual_parent, blessing_overlays)) or bound
		"dawn_vitality":
			bound = _connect_if_present(controller, &"healing_pulse", Callable(self, "_on_healing_pulse").bind(visual_parent, blessing_overlays)) or bound
		"shared_branch_vitality":
			_spawn_primitive(&"wind_burst", series_id, visual_parent, (controller.get_parent() as Node2D).global_position if controller.get_parent() is Node2D else Vector2.ZERO, Vector2.ZERO, blessing_overlays, 0.72)
			bound = true
	return bound


func spawn_contact(
	series_id: String,
	world_position: Vector2,
	visual_parent: Node,
	blessing_overlays: Array = []
) -> Node2D:
	var effect_id := &"wind_burst"
	if series_id in ["thorn", "arcane_swamp"]:
		effect_id = &"poison_splash"
	return _spawn_primitive(effect_id, series_id, visual_parent, world_position, Vector2.ZERO, blessing_overlays, 0.68)


func get_debug_state() -> Dictionary:
	return {
		"spawn_count": _spawn_count,
		"effect_counts": _effect_counts.duplicate(true),
	}


func _connect_if_present(controller: Node, signal_name: StringName, callable: Callable) -> bool:
	if not controller.has_signal(signal_name):
		return false
	controller.connect(signal_name, callable)
	return true


func _on_indexed_point(_index: int, world_position: Vector2, series_id: String, effect_id: StringName, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(effect_id, series_id, visual_parent, world_position, Vector2.ZERO, overlays)


func _on_target_point(_target: Node, world_position: Vector2, series_id: String, effect_id: StringName, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(effect_id, series_id, visual_parent, world_position, Vector2.ZERO, overlays, 1.08)


func _on_point_hit(_target: Node, world_position: Vector2, _damage: int, series_id: String, effect_id: StringName, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(effect_id, series_id, visual_parent, world_position, Vector2.ZERO, overlays, 0.72)


func _on_detonated(world_position: Vector2, hit_count: int, series_id: String, effect_id: StringName, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(effect_id, series_id, visual_parent, world_position, Vector2.ZERO, overlays, clampf(1.0 + float(hit_count) * 0.04, 1.0, 1.35))


func _on_volley(_origin: Vector2, target_positions: Array[Vector2], series_id: String, effect_id: StringName, visual_parent: Node, overlays: Array) -> void:
	for position in target_positions:
		_spawn_primitive(effect_id, series_id, visual_parent, position, Vector2.ZERO, overlays, 0.62)


func _on_drone_shot(_drone_index: int, origin: Vector2, _target: Node, target_position: Vector2, visual_parent: Node, overlays: Array) -> void:
	if visual_parent == null or not is_instance_valid(visual_parent):
		return
	var projectile := RASTER_EVENT_VFX.new() as Node2D
	visual_parent.add_child(projectile)
	projectile.call("play_stone_lance", origin, target_position)
	projectile.set_meta("blessing_overlays", overlays.duplicate(true))
	_record_spawn(&"wind_slash")


func _on_healing_pulse(amount: int, world_position: Vector2, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(&"wind_burst", "dawn_vitality", visual_parent, world_position, Vector2.ZERO, overlays, clampf(0.54 + float(amount) * 0.04, 0.54, 0.82))


func _on_lightning_chain(from_position: Vector2, _target: Node, target_position: Vector2, visual_parent: Node, overlays: Array) -> void:
	_spawn_primitive(&"lightning_bolt", "lightning", visual_parent, from_position, target_position, overlays, 0.74)


func _on_lightning_final(_target: Node, target_position: Vector2, visual_parent: Node, overlays: Array) -> void:
	if visual_parent == null or not is_instance_valid(visual_parent):
		return
	var strike := RASTER_EVENT_VFX.new() as Node2D
	visual_parent.add_child(strike)
	strike.call("play_lightning_sky_strike", target_position)
	strike.set_meta("blessing_overlays", overlays.duplicate(true))
	_record_spawn(&"lightning_impact")


func _spawn_primitive(
	effect_id: StringName,
	series_id: String,
	visual_parent: Node,
	origin: Vector2,
	target: Vector2,
	overlays: Array,
	scale_multiplier: float = 1.0
) -> Node2D:
	effect_id = _resolve_blessing_impact(effect_id, overlays)
	var packed := PRIMITIVE_SCENES.get(effect_id) as PackedScene
	if packed == null or visual_parent == null or not is_instance_valid(visual_parent):
		return null
	var primitive := packed.instantiate() as Node2D
	if primitive == null:
		return null
	primitive.set("auto_play", false)
	primitive.set("auto_free", true)
	primitive.set_meta("skill_series_id", series_id)
	primitive.set_meta("blessing_overlays", overlays.duplicate(true))
	visual_parent.add_child(primitive)
	var palette := _resolve_palette(series_id, overlays)
	primitive.call("configure_runtime", {
		"primary_color": palette[0],
		"secondary_color": palette[1],
		"intensity": 1.12,
		"effect_scale": scale_multiplier,
		"particle_amount": clampi(28 + overlays.size() * 6, 28, 64),
		"noise_amount": 0.48 + minf(0.22, float(overlays.size()) * 0.04),
		"glow_strength": 1.25 + minf(0.75, float(overlays.size()) * 0.12),
		"one_shot": true,
		"auto_free": true,
	})
	if effect_id in [&"lightning_bolt", &"wind_slash"] and origin != target:
		var authored_length := 320.0 if effect_id == &"lightning_bolt" else 292.0
		var distance_scale := origin.distance_to(target) / authored_length
		primitive.set(
			"effect_scale",
			distance_scale if effect_id == &"lightning_bolt" else clampf(distance_scale, 0.25, 2.2)
		)
		var midpoint := (origin + target) * 0.5
		primitive.call("play", midpoint, target)
	else:
		primitive.call("play", origin)
	_record_spawn(effect_id)
	return primitive


func _record_spawn(effect_id: StringName) -> void:
	_spawn_count += 1
	_effect_counts[String(effect_id)] = int(_effect_counts.get(String(effect_id), 0)) + 1


func _resolve_blessing_impact(effect_id: StringName, overlays: Array) -> StringName:
	# Chain bolts and the delayed sky strike are Lightning's readable attack
	# topology. Blessings may recolor them, but must not replace either shape.
	if effect_id in [&"lightning_bolt", &"lightning_impact", &"wind_slash"] or overlays.is_empty():
		return effect_id
	var strongest: Dictionary = {}
	for overlay_variant in overlays:
		if not overlay_variant is Dictionary:
			continue
		var overlay := overlay_variant as Dictionary
		if strongest.is_empty() or int(overlay.get("level", 1)) > int(strongest.get("level", 1)):
			strongest = overlay
	match String(strongest.get("element", "")):
		"fire": return &"fire_burst"
		"lightning": return &"lightning_impact"
		"water": return &"water_splash"
		"poison": return &"poison_splash"
		"ice": return &"ice_shatter"
		"wind": return &"wind_burst"
	return effect_id


func _resolve_palette(series_id: String, overlays: Array) -> Array[Color]:
	var base := SERIES_PALETTES.get(StringName(series_id), [Color.WHITE, Color("82d8ff")]) as Array
	var primary := base[0] as Color
	var secondary := base[1] as Color
	for overlay_variant in overlays:
		if not overlay_variant is Dictionary:
			continue
		var overlay := overlay_variant as Dictionary
		var tint := _element_tint(String(overlay.get("element", "")))
		var weight := clampf(0.12 + float(overlay.get("level", 1)) * 0.05, 0.12, 0.3)
		secondary = secondary.lerp(tint, weight)
		primary = primary.lerp(tint.lightened(0.32), weight * 0.55)
	return [primary, secondary]


func _element_tint(element: String) -> Color:
	match element:
		"fire": return Color("ff571d")
		"lightning": return Color("79dfff")
		"water": return Color("3ac7e8")
		"poison": return Color("98e24e")
		"ice": return Color("b7f4ff")
		"wind": return Color("a1e6bc")
		"light": return Color("fff0a5")
		"dark": return Color("8b5bc8")
	return Color.WHITE
