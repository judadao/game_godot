class_name DragonBreathMaterialVFX2D
extends Node2D

const HEAD_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dragon_breath__dragon_head.png")
const BEAM_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dragon_breath__breath_beam.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")
const BEAM_TILES_PER_HEAD := 3

var _emitters: Array[Dictionary] = []
var _tier_rank := 1
var _side_sweep_count := 1
var _rain_emitter_count := 0
var _radius := 390.0
var _head_scale := 0.20


func configure(source_sprites: Array, tier_rank: int, _palette: Array, parameters: Dictionary, _target_positions: Array = []) -> bool:
	clear()
	_tier_rank = clampi(tier_rank, 1, 3)
	_side_sweep_count = maxi(1, int(parameters.get("side_sweep_count", [1, 2, 2][_tier_rank - 1])))
	_rain_emitter_count = maxi(0, int(parameters.get("rain_emitter_count", [0, 0, 20][_tier_rank - 1])))
	_radius = maxf(240.0, float(parameters.get("radius", [390.0, 450.0, 540.0][_tier_rank - 1])))
	_head_scale = 0.20 + float(_tier_rank - 1) * 0.018
	for source in source_sprites:
		if source is Sprite2D:
			(source as Sprite2D).visible = false
	for side_index in _side_sweep_count:
		_build_emitter("side", side_index, -1 if side_index % 2 == 0 else 1)
	for rain_index in _rain_emitter_count:
		_build_emitter("rain", rain_index, 1)
	visible = true
	set_progress(0.0)
	return true


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_emitters.clear()
	visible = false


func set_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.90, 1.0, progress)
	for emitter_index in _emitters.size():
		var emitter := _emitters[emitter_index]
		var head := emitter.get("head") as Sprite2D
		var kind := String(emitter.get("kind", "side"))
		var index := int(emitter.get("index", 0))
		var direction := int(emitter.get("direction", 1))
		var active := true
		if kind == "side":
			var y_ratio := 0.5 + 0.5 * sin(progress * TAU * 1.15 + float(index) * PI)
			head.position = Vector2(float(direction) * 74.0, lerpf(-188.0, -38.0, y_ratio))
			head.flip_h = direction < 0
			head.rotation = float(direction) * sin(progress * TAU) * 0.10
		else:
			var rain_phase := clampf((progress - 0.36) / 0.54, 0.0, 1.0)
			var emitter_start := float(index) / float(maxi(1, _rain_emitter_count)) * 0.78
			var emitter_phase := (rain_phase - emitter_start) / 0.26
			active = emitter_phase > 0.0 and emitter_phase < 1.0
			var column := index / 2
			var column_count := ceili(float(_rain_emitter_count) / 2.0)
			var ratio := (float(column) + 0.5) / float(maxi(1, column_count))
			head.position = Vector2(lerpf(-_radius, _radius, ratio), -312.0 + float(index % 2) * 62.0)
			head.rotation = PI * 0.5 + sin(progress * TAU * 1.8 + float(index)) * 0.10
			head.flip_h = false
		var kind_scale := 1.0 if kind == "side" else 0.76
		head.scale = Vector2.ONE * _head_scale * kind_scale * (0.94 + sin(progress * TAU * 4.0 + emitter_index) * 0.06)
		head.modulate.a = fade if active else 0.0
		head.visible = active and fade > 0.02
		var beams := emitter.get("beams", []) as Array
		for tile_index in beams.size():
			var beam := beams[tile_index] as Sprite2D
			var pulse := 0.92 + sin(progress * TAU * 9.0 + float(tile_index + emitter_index)) * 0.08
			if kind == "side":
				beam.rotation = 0.0 if direction > 0 else PI
				beam.flip_h = direction > 0
				beam.position = head.position + Vector2(float(direction) * (92.0 + float(tile_index) * 96.0), 8.0)
				beam.scale = Vector2(0.17, 0.16 * pulse)
			else:
				beam.rotation = PI * 0.5
				beam.flip_h = true
				beam.position = head.position + Vector2(0.0, 70.0 + float(tile_index) * 45.0)
				beam.scale = Vector2(0.14, 0.16 * pulse)
			beam.modulate.a = fade * (0.82 + 0.18 * pulse) if active else 0.0
			beam.visible = active and fade > 0.02


func get_active_layer_count() -> int:
	return _emitters.size() * (1 + BEAM_TILES_PER_HEAD)


func get_debug_state() -> Dictionary:
	return {
		"renderer": "sweeping_dragon_head_beam",
		"visual_family": "dragon_breath",
		"tier_rank": _tier_rank,
		"head_texture": HEAD_TEXTURE.resource_path,
		"beam_texture": BEAM_TEXTURE.resource_path,
		"head_count": _emitters.size(),
		"beam_tile_count": _emitters.size() * BEAM_TILES_PER_HEAD,
		"beam_tile_stride": 96.0,
		"side_sweep_count": _side_sweep_count,
		"rain_emitter_count": _rain_emitter_count,
		"head_scale": _head_scale,
		"side_head_y_sweep_span": 150.0,
		"line_layer_count": 0,
		"blessing_mutable": true,
		"layer_count": get_active_layer_count(),
	}


func _build_emitter(kind: String, index: int, direction: int) -> void:
	var head := Sprite2D.new()
	head.name = "%sDragonHead%02d" % [kind.capitalize(), index + 1]
	head.texture = HEAD_TEXTURE
	head.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	head.material = _edge_material()
	head.z_index = 12
	add_child(head)
	var beams: Array[Sprite2D] = []
	for tile_index in BEAM_TILES_PER_HEAD:
		var beam := Sprite2D.new()
		beam.name = "%sBreathBeam%02dTile%02d" % [kind.capitalize(), index + 1, tile_index + 1]
		beam.texture = BEAM_TEXTURE
		beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		beam.material = _edge_material()
		beam.z_index = 8 - tile_index
		add_child(beam)
		beams.append(beam)
	_emitters.append({"kind": kind, "index": index, "direction": direction, "head": head, "beams": beams})


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result
