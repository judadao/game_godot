class_name DrStoneMaterialVFX2D
extends Node2D

const DRONE_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_orbit.png")
const PROJECTILE_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_lance.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")
const LANCE_SHADER := preload("res://shaders/vfx/stone_lance_core_preserve.gdshader")
const LAYER_IDS := ["stone_core", "levitation_runes", "thruster_debris", "shot_trails", "impact_bursts", "crash_sequence"]

var _drones: Array[Sprite2D] = []
var _projectiles: Array[Sprite2D] = []
var _tier := 1
var _drone_count := 3
var _duration := 5.0
var _progress := 0.0
var _refill_generation := 0


func configure(source_sprites: Array, tier_rank: int, _palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_drone_count = maxi(3, int(parameters.get("drone_count", [3, 6, 10][_tier - 1])))
	_duration = maxf(0.5, float(parameters.get("duration_seconds", [5.0, 7.0, 9.0][_tier - 1])))
	var cleanup_material := _edge_material()
	for source in source_sprites:
		if source is Sprite2D:
			(source as Sprite2D).visible = false
	for index in _drone_count:
		var drone := Sprite2D.new()
		drone.name = "StoneOrbitDrone%02d" % (index + 1)
		drone.texture = DRONE_TEXTURE
		drone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		drone.material = cleanup_material
		drone.scale = Vector2.ONE * (0.105 + float(_tier) * 0.007)
		drone.z_index = 8
		add_child(drone)
		_drones.append(drone)
		var projectile := Sprite2D.new()
		projectile.name = "StoneLance%02d" % (index + 1)
		projectile.texture = PROJECTILE_TEXTURE
		projectile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# The lance needs its own material because the bright trail otherwise
		# overwhelms the authored dark stone core at combat scale.
		projectile.material = _lance_material()
		projectile.scale = Vector2(0.18, 0.18)
		projectile.z_index = 12
		projectile.visible = false
		add_child(projectile)
		_projectiles.append(projectile)
	_refill_generation = 1
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_drones.clear()
	_projectiles.clear()
	_progress = 0.0
	_refill_generation = 0
	visible = false


func refill() -> int:
	_refill_generation += 1
	set_progress(0.0)
	return _drones.size()


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var reveal := smoothstep(0.0, 0.10, _progress)
	var crash := smoothstep(0.84, 1.0, _progress)
	for index in _drones.size():
		var drone := _drones[index]
		var orbit_angle := TAU * float(index) / float(maxi(1, _drones.size())) + _progress * TAU * (0.34 + float(_tier) * 0.05)
		var orbit_radius := 92.0 + float(_tier) * 16.0 + float(index % 2) * 22.0
		var position_value := Vector2(cos(orbit_angle) * orbit_radius, -112.0 + sin(orbit_angle) * 54.0)
		position_value += Vector2(0.0, crash * crash * (190.0 + float(index % 3) * 24.0))
		drone.position = position_value
		drone.rotation = _progress * TAU * (0.65 if index % 2 == 0 else -0.65)
		drone.modulate.a = reveal * (1.0 - crash)
		drone.visible = drone.modulate.a > 0.01
		var projectile := _projectiles[index]
		var shot_phase := fposmod(_progress * _duration / maxf(0.18, 0.62 - float(_tier) * 0.08) + float(index) / float(_drones.size()), 1.0)
		var direction := Vector2(1.0 if index % 2 == 0 else -1.0, 0.18 + float(index % 3) * 0.12).normalized()
		projectile.position = position_value + direction * lerpf(18.0, 150.0 + float(_tier) * 26.0, shot_phase)
		projectile.rotation = direction.angle()
		projectile.modulate.a = lerpf(0.72, 1.0, sin(shot_phase * PI)) * (1.0 - crash)
		projectile.visible = reveal > 0.01 and projectile.modulate.a > 0.04


func get_debug_state() -> Dictionary:
	return {
		"renderer": "blessing_mutable_stone_drone_squad",
		"layer_ids": LAYER_IDS.duplicate(),
		"blessing_mutable": true,
		"mutable_channels": ["stone_material", "projectile_shape", "shot_trajectory", "impact_primitive", "crash_residue"],
		"tier_rank": _tier,
		"drone_count": _drone_count,
		"duration_seconds": _duration,
		"drone_texture": DRONE_TEXTURE.resource_path,
		"projectile_texture": PROJECTILE_TEXTURE.resource_path,
		"projectile_material_shader": LANCE_SHADER.resource_path,
		"projectile_sprite_count": _projectiles.size(),
		"visible_line_count": 0,
		"real_visual_layer_count": get_active_layer_count(),
		"refill_generation": _refill_generation,
	}


func get_active_layer_count() -> int:
	return _drones.size() + _projectiles.size()


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result


func _lance_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = LANCE_SHADER
	return result
