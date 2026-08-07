class_name ThornBloomMaterialVFX2D
extends Node2D

const BLOOM_ATLAS_PATH := "res://assets/generated/vfx/finisher_parts_v4/plant_growth_sequence.png"
const LAYER_IDS := ["ground_cracks", "thorn_tendrils", "bloom_sequence", "spike_barrage", "petal_decay"]

var _core_sprites: Array[Sprite2D] = []
var _tendrils: Array[Line2D] = []
var _blooms: Array[Sprite2D] = []
var _palette: Array[Color] = [Color("f5ffc2"), Color("7fd05e"), Color("6b285f")]
var _tier := 1
var _thorn_count := 3
var _radius := 180.0
var _duration := 2.4
var _progress := 0.0
var _bloom_texture: Texture2D


func configure(core_sprites: Array, tier_rank: int, palette: Array, parameters: Dictionary) -> bool:
	clear()
	_tier = clampi(tier_rank, 1, 3)
	_thorn_count = maxi(3, int(parameters.get("thorn_count", [3, 6, 10][_tier - 1])))
	_radius = maxf(48.0, float(parameters.get("radius", [180.0, 240.0, 310.0][_tier - 1])))
	_duration = maxf(0.2, float(parameters.get("duration_seconds", [2.4, 3.0, 3.8][_tier - 1])))
	if palette.size() >= 3:
		_palette.assign([palette[0] as Color, palette[1] as Color, palette[2] as Color])
	for core_variant in core_sprites:
		if core_variant is Sprite2D:
			var core := core_variant as Sprite2D
			core.visible = false
			_core_sprites.append(core)
	_bloom_texture = load(String(parameters.get("bloom_asset_path", BLOOM_ATLAS_PATH))) as Texture2D
	for index in _thorn_count:
		_build_tendril(index)
		_build_bloom(index)
	visible = true
	set_progress(0.0)
	return _bloom_texture != null


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_core_sprites.clear()
	_tendrils.clear()
	_blooms.clear()
	_progress = 0.0
	visible = false


func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	var emerge := smoothstep(0.02, 0.24, _progress)
	var bloom := smoothstep(0.20, 0.42, _progress)
	var decay := smoothstep(0.84, 1.0, _progress)
	for index in _tendrils.size():
		var stagger := float(index) / maxf(1.0, float(_tendrils.size())) * 0.13
		var local_emerge := smoothstep(stagger, stagger + 0.22, _progress)
		var tendril := _tendrils[index]
		tendril.visible = local_emerge > 0.01
		tendril.modulate.a = local_emerge * (1.0 - decay)
		tendril.scale.y = local_emerge
		var flower := _blooms[index]
		var local_bloom := smoothstep(0.19 + stagger, 0.36 + stagger, _progress)
		flower.visible = local_bloom > 0.01
		flower.modulate.a = local_bloom * (1.0 - decay)
		flower.scale = Vector2.ONE * lerpf(0.18, 0.32 + _tier * 0.025, local_bloom)
		if flower.texture is AtlasTexture:
			var frame := clampi(floori(local_bloom * 5.99), 0, 5)
			(flower.texture as AtlasTexture).region = Rect2((frame % 3) * 512, (frame / 3) * 512, 512, 512)
	for index in _blooms.size():
		_blooms[index].rotation = sin(_progress * TAU * 2.0 + index) * 0.08
	queue_redraw()


func get_debug_state() -> Dictionary:
	return {
		"renderer": "thorn_emerge_bloom_barrage",
		"layer_ids": LAYER_IDS.duplicate(),
		"tier_rank": _tier,
		"thorn_count": _thorn_count,
		"radius": _radius,
		"duration_seconds": _duration,
		"real_visual_layer_count": 3 + _tendrils.size() + _blooms.size(),
		"reuses_authored_bloom_frames": _bloom_texture != null and _bloom_texture.resource_path == BLOOM_ATLAS_PATH,
		"bloom_asset_path": BLOOM_ATLAS_PATH,
	}


func get_active_layer_count() -> int:
	return 3 + _tendrils.size() + _blooms.size()


func _draw() -> void:
	var reveal := smoothstep(0.0, 0.18, _progress)
	var decay := smoothstep(0.84, 1.0, _progress)
	for index in _thorn_count:
		var angle := TAU * float(index) / float(_thorn_count) + float(index % 2) * 0.22
		var end := Vector2.from_angle(angle) * _radius * (0.38 + float(index % 3) * 0.16)
		draw_polyline(PackedVector2Array([Vector2.ZERO, end * 0.45, end]), Color(_palette[2], 0.62 * reveal * (1.0 - decay)), 3.0)
	if _progress > 0.38 and _progress < 0.88:
		var pulse := 0.55 + sin(_progress * TAU * 12.0) * 0.35
		for index in _thorn_count:
			var source := _thorn_position(index)
			var direction := source.normalized()
			draw_line(source, source + direction * (42.0 + _tier * 10.0), Color(_palette[0], pulse), 3.0)
	if decay > 0.0:
		for index in _thorn_count * 2:
			var angle := float(index) * 2.399
			var position := Vector2.from_angle(angle) * _radius * 0.45 + Vector2(0.0, decay * 34.0)
			draw_circle(position, 3.0 + float(index % 2), Color(_palette[1], 1.0 - decay))


func _build_tendril(index: int) -> void:
	var tendril := Line2D.new()
	tendril.name = "ThornTendril%02d" % index
	tendril.width = 8.0 + _tier * 1.5
	tendril.default_color = _palette[1].lerp(_palette[2], 0.46)
	tendril.joint_mode = Line2D.LINE_JOINT_ROUND
	tendril.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(sin(index * 1.7) * 12.0, -28.0),
		Vector2(cos(index * 1.3) * 18.0, -58.0 - float(index % 3) * 10.0),
	])
	tendril.position = _thorn_position(index)
	add_child(tendril)
	_tendrils.append(tendril)


func _build_bloom(index: int) -> void:
	var flower := Sprite2D.new()
	flower.name = "Bloom%02d" % index
	if _bloom_texture != null:
		var region := AtlasTexture.new()
		region.atlas = _bloom_texture
		region.region = Rect2(0, 0, 512, 512)
		flower.texture = region
	flower.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flower.position = _thorn_position(index) + Vector2(0.0, -64.0 - float(index % 3) * 10.0)
	flower.modulate = Color(_palette[0], 0.0)
	add_child(flower)
	_blooms.append(flower)


func _thorn_position(index: int) -> Vector2:
	var angle := TAU * float(index) / maxf(1.0, float(_thorn_count)) + float(index % 2) * 0.19
	var distance := _radius * (0.24 + float(index % 3) * 0.13)
	return Vector2.from_angle(angle) * distance
