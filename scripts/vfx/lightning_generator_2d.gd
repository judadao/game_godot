class_name LightningGenerator2D
extends Node2D

@export var start_point := Vector2.ZERO
@export var end_point := Vector2(220.0, 0.0)
@export_range(2, 8, 1) var subdivisions := 6
@export_range(0.0, 96.0, 0.5) var displacement := 28.0
@export_range(0.0, 1.0, 0.01) var branch_chance := 0.34
@export_range(0.01, 0.2, 0.005) var refresh_interval := 0.045
@export_range(0.5, 18.0, 0.5) var width := 4.0
@export var bolt_color := Color(0.86, 0.97, 1.0, 1.0)
@export var glow_color := Color(0.28, 0.62, 1.0, 0.42)
@export var animated := true
@export var random_seed := 7127

var _elapsed := 0.0
var _generation := 0
var _main_points := PackedVector2Array()
var _branches: Array[PackedVector2Array] = []


func _ready() -> void:
	regenerate()


func _process(delta: float) -> void:
	if not animated:
		return
	_elapsed += delta
	if _elapsed < refresh_interval:
		return
	_elapsed = fmod(_elapsed, refresh_interval)
	regenerate()


func set_endpoints(from: Vector2, to: Vector2) -> void:
	start_point = from
	end_point = to
	regenerate()


func regenerate() -> void:
	_generation += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed + _generation * 104729
	_main_points = _subdivide(start_point, end_point, subdivisions, displacement, rng)
	_branches.clear()
	for point_index in range(2, _main_points.size() - 2):
		if rng.randf() > branch_chance:
			continue
		var tangent := (_main_points[point_index + 1] - _main_points[point_index - 1]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var branch_length := rng.randf_range(28.0, 68.0)
		var branch_end := _main_points[point_index] + tangent * branch_length * 0.42 + normal * branch_length * rng.randf_range(-1.0, 1.0)
		_branches.append(_subdivide(_main_points[point_index], branch_end, maxi(2, subdivisions - 2), displacement * 0.42, rng))
	queue_redraw()


func get_main_points() -> PackedVector2Array:
	return _main_points


func get_branch_count() -> int:
	return _branches.size()


func _draw() -> void:
	if _main_points.size() < 2:
		return
	draw_polyline(_main_points, glow_color, width * 3.4, false)
	draw_polyline(_main_points, bolt_color, width, false)
	for branch in _branches:
		draw_polyline(branch, Color(glow_color, glow_color.a * 0.65), width * 1.8, false)
		draw_polyline(branch, Color(bolt_color, bolt_color.a * 0.8), maxf(1.0, width * 0.45), false)


func _subdivide(from: Vector2, to: Vector2, depth: int, offset: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var points := PackedVector2Array([from, to])
	var current_offset := offset
	for _step in depth:
		var next_points := PackedVector2Array()
		for index in range(points.size() - 1):
			var a := points[index]
			var b := points[index + 1]
			var tangent := (b - a).normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var midpoint := (a + b) * 0.5 + normal * rng.randf_range(-current_offset, current_offset)
			next_points.append(a)
			next_points.append(midpoint)
		next_points.append(points[-1])
		points = next_points
		current_offset *= 0.52
	return points
