extends Node2D

const CLOCK_MINUTE_POINTS: Array[Vector2] = [
	Vector2(0, -15), Vector2(7, -13), Vector2(13, -7), Vector2(15, 0),
	Vector2(13, 7), Vector2(7, 13), Vector2(0, 15), Vector2(-7, 13),
	Vector2(-13, 7), Vector2(-15, 0), Vector2(-13, -7), Vector2(-7, -13),
]
@onready var window_lights: Node2D = $WindowLights
@onready var forge_warmth: Node2D = $ForgeWarmth
@onready var cloth_motions: Node2D = $ClothMotions
@onready var clock_mechanism: Node2D = $ClockMechanism
@onready var mechanical_details: Node2D = $MechanicalDetails
@onready var metal_glints: Node2D = $MetalGlints

var _elapsed := 0.0
var _window_groups: Array[Dictionary] = []
var _cloth_groups: Array[Dictionary] = []
var _glint_groups: Array[Dictionary] = []


func _ready() -> void:
	for child in window_lights.get_children():
		var group := child as Node2D
		if group == null:
			continue
		_window_groups.append({
			"node": group,
			"period": float(group.get_meta("period", 3.5)),
			"phase": float(group.get_meta("phase", 0.0)),
			"base_alpha": float(group.get_meta("base_alpha", 0.72)),
		})
	for child in cloth_motions.get_children():
		var pivot := child as Node2D
		if pivot == null:
			continue
		_cloth_groups.append({
			"node": pivot,
			"base_position": pivot.position,
			"period": float(pivot.get_meta("period", 3.8)),
			"phase": float(pivot.get_meta("phase", 0.0)),
			"max_offset": float(pivot.get_meta("max_offset", 1.0)),
		})
	for child in metal_glints.get_children():
		var glint := child as Node2D
		if glint == null:
			continue
		_glint_groups.append({
			"node": glint,
			"base_position": glint.position,
			"interval": float(glint.get_meta("interval", 6.0)),
			"duration": float(glint.get_meta("duration", 0.2)),
			"phase": float(glint.get_meta("phase", 0.0)),
			"travel": glint.get_meta("travel", Vector2(4, 0)) as Vector2,
		})
	_update_presentation()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_presentation()


func get_building_animation_contract() -> Dictionary:
	return {
		"window_groups": window_lights.get_child_count(),
		"cloth_groups": cloth_motions.get_child_count(),
		"metal_glints": metal_glints.get_child_count(),
		"forge_warmth": forge_warmth.get_node_or_null("HearthCore") != null,
		"clock_ticks": clock_mechanism.get_node_or_null("MinuteHand") != null,
		"blueprint_gear": mechanical_details.get_node_or_null("BlueprintGear") != null,
		"editor_authored": true,
		"collision_owned": false,
	}


func _update_presentation() -> void:
	_update_window_lights()
	_update_forge_warmth()
	_update_cloth_motions()
	_update_clock()
	_update_mechanical_details()
	_update_metal_glints()


func _update_window_lights() -> void:
	for window in _window_groups:
		var group := window["node"] as Node2D
		var period := float(window["period"])
		var phase := float(window["phase"])
		var base_alpha := float(window["base_alpha"])
		var slow := sin(_elapsed * TAU / period + phase)
		var ember := sin(_elapsed * TAU / (period * 0.47) + phase * 1.71)
		# Windows stay lit. Only the fire colour and intensity drift by roughly
		# ten percent, with a second tiny ember rhythm to avoid synchronized pulses.
		var strength := snappedf(clampf(0.91 + slow * 0.06 + ember * 0.025, 0.82, 1.0), 0.02)
		group.modulate = Color(1.0, 0.92 + strength * 0.08, 0.76 + strength * 0.12, base_alpha * strength)


func _update_forge_warmth() -> void:
	var core := forge_warmth.get_node("HearthCore") as AnimatedSprite2D
	var embers := forge_warmth.get_node("HearthEmbers") as Polygon2D
	var wall_bounce := forge_warmth.get_node("WallBounce") as Polygon2D
	var frame_strength := 0.84 + float(core.frame % 4) * 0.04
	core.modulate = Color(1.0, 0.94, 0.82, frame_strength)
	var bounce := 0.72 + sin(_elapsed * TAU / 1.05 + 0.8) * 0.16
	embers.modulate.a = 0.76 + float(core.frame % 2) * 0.18
	wall_bounce.modulate.a = bounce


func _update_cloth_motions() -> void:
	for cloth in _cloth_groups:
		var pivot := cloth["node"] as Node2D
		var base_position := cloth["base_position"] as Vector2
		var period := float(cloth["period"])
		var phase := float(cloth["phase"])
		var max_offset := float(cloth["max_offset"])
		var offset_step := roundf(sin(_elapsed * TAU / period + phase) * max_offset)
		pivot.position = base_position + Vector2(offset_step, 0.0)


func _update_clock() -> void:
	var step_seconds := float(clock_mechanism.get_meta("step_seconds", 1.0))
	var second_index := int(floor(_elapsed / step_seconds)) % CLOCK_MINUTE_POINTS.size()
	var second_hand := clock_mechanism.get_node("SecondHand") as Line2D
	second_hand.points = PackedVector2Array([Vector2.ZERO, CLOCK_MINUTE_POINTS[second_index]])


func _update_mechanical_details() -> void:
	var gear := mechanical_details.get_node("BlueprintGear") as Node2D
	var step_seconds := float(gear.get_meta("step_seconds", 0.55))
	var hand_drawn := gear.get_node("HandDrawnGear") as AnimatedSprite2D
	var frame_count := hand_drawn.sprite_frames.get_frame_count(&"rotate")
	hand_drawn.frame = int(floor(_elapsed / step_seconds)) % frame_count


func _update_metal_glints() -> void:
	for glint in _glint_groups:
		var node := glint["node"] as Node2D
		var interval := float(glint["interval"])
		var duration := float(glint["duration"])
		var phase := float(glint["phase"])
		var event_time := fposmod(_elapsed + phase, interval)
		if event_time >= duration:
			node.visible = false
			continue
		var step := mini(2, int(floor(event_time / duration * 3.0)))
		var base_position := glint["base_position"] as Vector2
		var travel := glint["travel"] as Vector2
		node.visible = true
		node.position = base_position + (travel * float(step) / 2.0).round()
		node.modulate.a = 0.55 if step != 1 else 1.0
		var hand_drawn := node.get_node_or_null("HandDrawnReflection") as AnimatedSprite2D
		if hand_drawn != null:
			var frame_count := hand_drawn.sprite_frames.get_frame_count(&"glint")
			hand_drawn.frame = mini(
				frame_count - 1,
				int(floor(event_time / duration * float(frame_count)))
			)
			node.modulate.a = 1.0
