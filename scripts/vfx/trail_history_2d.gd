class_name TrailHistory2D
extends Line2D

@export_range(2, 96, 1) var max_points := 28
@export_range(0.1, 32.0, 0.1) var minimum_distance := 4.0
@export_range(0.01, 2.0, 0.01) var fade_duration := 0.28
@export var target_path: NodePath

var _target: Node2D
var _ages: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node2D
	if width_curve == null:
		var taper := Curve.new()
		taper.add_point(Vector2(0.0, 0.0))
		taper.add_point(Vector2(0.24, 0.75))
		taper.add_point(Vector2(1.0, 1.0))
		width_curve = taper


func _process(delta: float) -> void:
	for index in _ages.size():
		_ages[index] += delta
	while not _ages.is_empty() and _ages[0] >= fade_duration:
		_ages.remove_at(0)
		remove_point(0)
	if _target != null:
		push_world_point(_target.global_position)
	modulate.a = 0.0 if _ages.is_empty() else clampf(1.0 - _ages[0] / fade_duration, 0.0, 1.0)


func push_world_point(world_point: Vector2) -> void:
	var local_point := to_local(world_point)
	if get_point_count() > 0 and get_point_position(get_point_count() - 1).distance_to(local_point) < minimum_distance:
		return
	add_point(local_point)
	_ages.append(0.0)
	while get_point_count() > max_points:
		remove_point(0)
		_ages.remove_at(0)


func clear_history() -> void:
	clear_points()
	_ages.clear()
