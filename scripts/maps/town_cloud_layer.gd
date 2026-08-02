extends Node2D

@export var wrap_left := -500.0
@export var wrap_right := 2442.0

var _elapsed := 0.0
var _cloud_state: Dictionary = {}


func _ready() -> void:
	add_to_group("town_lighting_target")
	for child in get_children():
		var cloud := child as Sprite2D
		if cloud == null:
			continue
		_cloud_state[cloud.get_instance_id()] = {
			"base_y": cloud.position.y,
			"phase": float(cloud.get_meta("sway_phase", 0.0)),
		}


func _process(delta: float) -> void:
	advance_clouds(delta)


func advance_clouds(delta: float) -> void:
	_elapsed += maxf(delta, 0.0)
	for child in get_children():
		var cloud := child as Sprite2D
		if cloud == null or cloud.texture == null:
			continue
		var speed := float(cloud.get_meta("drift_speed", 10.0))
		cloud.position.x += speed * delta
		var half_width := cloud.texture.get_width() * absf(cloud.scale.x) * 0.5
		if cloud.position.x - half_width > wrap_right:
			cloud.position.x = wrap_left - half_width
		var state := _cloud_state.get(cloud.get_instance_id(), {}) as Dictionary
		var base_y := float(state.get("base_y", cloud.position.y))
		var phase := float(state.get("phase", 0.0))
		var amplitude := float(cloud.get_meta("sway_amplitude", 2.0))
		var period := maxf(float(cloud.get_meta("sway_period", 16.0)), 0.1)
		cloud.position.y = base_y + sin(_elapsed * TAU / period + phase) * amplitude


func set_cloud_tint(tint: Color) -> void:
	for child in get_children():
		var cloud := child as Sprite2D
		if cloud != null:
			var shader_material := cloud.material as ShaderMaterial
			if shader_material != null:
				shader_material.set_shader_parameter("cloud_tint", tint)


func get_cloud_motion_contract() -> Dictionary:
	var speed_count: Dictionary = {}
	var cloud_count := 0
	for child in get_children():
		var cloud := child as Sprite2D
		if cloud == null:
			continue
		cloud_count += 1
		speed_count[float(cloud.get_meta("drift_speed", 0.0))] = true
	return {
		"cloud_count": cloud_count,
		"distinct_speeds": speed_count.size(),
		"wrap_left": wrap_left,
		"wrap_right": wrap_right,
	}
