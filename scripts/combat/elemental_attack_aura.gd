class_name ElementalAttackAura
extends Node2D

const MIN_INTENSITY := 1
const MAX_INTENSITY := 5
const FIRE_TONGUE_BASE_AMOUNT := 10
const FIRE_SPARK_BASE_AMOUNT := 7
const FROST_CRYSTAL_BASE_AMOUNT := 8
const COLD_MIST_BASE_AMOUNT := 6

@export_range(20.0, 96.0, 1.0) var orbit_radius := 42.0
@export_range(0.0, 30.0, 0.1) var auto_expire_seconds := 0.0

@onready var fire_layer: Node2D = $FireLayer
@onready var flame_tongue: GPUParticles2D = $FireLayer/FlameTongue
@onready var sparks: GPUParticles2D = $FireLayer/Sparks
@onready var fire_ribbon: Line2D = $FireLayer/FireRibbon
@onready var ice_layer: Node2D = $IceLayer
@onready var frost_crystals: GPUParticles2D = $IceLayer/FrostCrystals
@onready var cold_mist: GPUParticles2D = $IceLayer/ColdMist
@onready var frost_arc: Line2D = $IceLayer/FrostArc
@onready var frost_arc_echo: Line2D = $IceLayer/FrostArcEcho

var _elements: Array[StringName] = []
var _intensity := MIN_INTENSITY
var _active := false
var _phase := 0.0
var _remaining_lifetime := 0.0


func _ready() -> void:
	_apply_visual_state()


func _process(delta: float) -> void:
	if not _active:
		return
	_phase = fmod(_phase + delta * (1.8 + float(_intensity) * 0.12), TAU)
	_update_fire_ribbon()
	_update_frost_arcs()
	if auto_expire_seconds <= 0.0:
		return
	_remaining_lifetime = maxf(0.0, _remaining_lifetime - delta)
	if is_zero_approx(_remaining_lifetime):
		set_active(false)


func configure(elements: Array, intensity: int) -> void:
	_elements = _normalize_elements(elements)
	_intensity = clampi(intensity, MIN_INTENSITY, MAX_INTENSITY)
	_active = not _elements.is_empty()
	_remaining_lifetime = auto_expire_seconds
	if is_node_ready():
		_apply_visual_state()


func set_active(value: bool) -> void:
	_active = value and not _elements.is_empty()
	if _active and auto_expire_seconds > 0.0:
		_remaining_lifetime = auto_expire_seconds
	if is_node_ready():
		_apply_visual_state()


func set_lifetime(seconds: float) -> void:
	auto_expire_seconds = maxf(0.0, seconds)
	_remaining_lifetime = auto_expire_seconds


func get_element_layer_count() -> int:
	return _elements.size()


func get_active_elements() -> Array[StringName]:
	return _elements.duplicate()


func get_intensity() -> int:
	return _intensity


func get_particle_budget() -> int:
	if not is_node_ready():
		return 0
	var budget := 0
	if &"flame" in _elements:
		budget += flame_tongue.amount + sparks.amount
	if &"frost" in _elements:
		budget += frost_crystals.amount + cold_mist.amount
	return budget


func is_active() -> bool:
	return _active


func _normalize_elements(elements: Array) -> Array[StringName]:
	var normalized: Array[StringName] = []
	for candidate in elements:
		var element := StringName(String(candidate).strip_edges().to_lower())
		match element:
			&"fire", &"flame":
				if not normalized.has(&"flame"):
					normalized.append(&"flame")
			&"ice", &"frost":
				if not normalized.has(&"frost"):
					normalized.append(&"frost")
	return normalized


func _apply_visual_state() -> void:
	var fire_enabled := _active and &"flame" in _elements
	var frost_enabled := _active and &"frost" in _elements
	fire_layer.visible = fire_enabled
	ice_layer.visible = frost_enabled
	flame_tongue.emitting = fire_enabled
	sparks.emitting = fire_enabled
	frost_crystals.emitting = frost_enabled
	cold_mist.emitting = frost_enabled
	fire_ribbon.visible = fire_enabled
	frost_arc.visible = frost_enabled
	frost_arc_echo.visible = frost_enabled
	flame_tongue.amount = FIRE_TONGUE_BASE_AMOUNT * _intensity
	sparks.amount = FIRE_SPARK_BASE_AMOUNT * _intensity
	frost_crystals.amount = FROST_CRYSTAL_BASE_AMOUNT * _intensity
	cold_mist.amount = COLD_MIST_BASE_AMOUNT * _intensity
	var intensity_scale := 0.82 + float(_intensity) * 0.11
	fire_layer.scale = Vector2.ONE * intensity_scale
	ice_layer.scale = Vector2.ONE * intensity_scale
	set_process(_active)
	if fire_enabled:
		flame_tongue.restart()
		sparks.restart()
	if frost_enabled:
		frost_crystals.restart()
		cold_mist.restart()
	_update_fire_ribbon()
	_update_frost_arcs()


func _update_fire_ribbon() -> void:
	if not is_node_ready():
		return
	var points := PackedVector2Array()
	var point_count := 17
	for index in point_count:
		var progress := float(index) / float(point_count - 1)
		var angle := _phase + progress * TAU * 1.45
		var radius := orbit_radius * (0.72 + sin(progress * PI) * 0.22)
		var height := lerpf(22.0, -34.0, progress)
		points.append(Vector2(cos(angle) * radius, height + sin(angle) * 8.0))
	fire_ribbon.points = points


func _update_frost_arcs() -> void:
	if not is_node_ready():
		return
	frost_arc.points = _arc_points(_phase * -0.72, 0.08, 0.82, orbit_radius + 5.0)
	frost_arc_echo.points = _arc_points(_phase * 0.58 + PI, 0.52, 1.22, orbit_radius - 4.0)


func _arc_points(phase: float, start_turn: float, end_turn: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var point_count := 15
	for index in point_count:
		var progress := float(index) / float(point_count - 1)
		var angle := phase + lerpf(start_turn, end_turn, progress) * TAU
		var vertical_radius := radius * 0.46
		points.append(Vector2(cos(angle) * radius, sin(angle) * vertical_radius - 7.0))
	return points
