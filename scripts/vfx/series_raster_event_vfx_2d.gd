class_name SeriesRasterEventVFX2D
extends Node2D

const STONE_LANCE_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/dr_stone__stone_lance.png")
const CHAIN_BOLT_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/lightning__chain_bolt.png")
const SKY_IMPACT_TEXTURE := preload("res://assets/generated/vfx/skill_materials/components/base/lightning__sky_impact.png")
const EDGE_SHADER := preload("res://shaders/vfx/authored_raster_edge_cleanup.gdshader")

var effect_id: StringName = &""


func play_stone_lance(origin: Vector2, target: Vector2) -> void:
	name = "StoneLanceVFX"
	effect_id = &"wind_slash"
	global_position = origin
	set_meta("skill_series_id", "dr_stone")
	set_meta("projectile_texture", STONE_LANCE_TEXTURE.resource_path)
	var sprite := Sprite2D.new()
	sprite.name = "StoneLance"
	sprite.texture = STONE_LANCE_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.material = _edge_material()
	sprite.scale = Vector2.ONE * 0.18
	sprite.rotation = origin.angle_to_point(target)
	add_child(sprite)
	var destination := target - origin
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + destination, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.22).set_delay(0.09)
	tween.chain().tween_callback(queue_free)


func play_lightning_sky_strike(target: Vector2) -> void:
	name = "LightningSkyStrikeVFX"
	effect_id = &"lightning_impact"
	global_position = target
	set_meta("skill_series_id", "lightning")
	set_meta("bolt_texture", CHAIN_BOLT_TEXTURE.resource_path)
	set_meta("impact_texture", SKY_IMPACT_TEXTURE.resource_path)
	set_meta("afterimage_count", 4)
	set_meta("vertical_descent", true)
	set_meta("ground_anchored_impact", true)
	for index in 4:
		var bolt := Sprite2D.new()
		bolt.name = "DescendingBoltAfterimage%02d" % (index + 1)
		bolt.texture = CHAIN_BOLT_TEXTURE
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		bolt.material = _edge_material()
		bolt.rotation = PI * 0.5
		bolt.scale = Vector2(0.18, 0.16 + float(index) * 0.012)
		bolt.position = Vector2(sin(float(index) * 2.3) * 8.0, -350.0 + float(index) * 72.0)
		bolt.modulate.a = 0.24 + float(index) * 0.16
		bolt.z_index = 8 + index
		add_child(bolt)
		var bolt_tween := create_tween()
		bolt_tween.set_parallel(true)
		bolt_tween.tween_property(bolt, "position:y", -72.0 + float(index) * 10.0, 0.12 + float(index) * 0.018).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		bolt_tween.tween_property(bolt, "modulate:a", 0.0, 0.16).set_delay(0.06 + float(index) * 0.012)
	var impact := Sprite2D.new()
	impact.name = "GroundSkyImpact"
	impact.texture = SKY_IMPACT_TEXTURE
	impact.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	impact.material = _edge_material()
	var impact_scale := 0.30
	impact.position = Vector2(0.0, -float(SKY_IMPACT_TEXTURE.get_height()) * impact_scale * 0.5)
	impact.scale = Vector2.ONE * impact_scale * 0.12
	impact.modulate.a = 0.0
	impact.z_index = 20
	add_child(impact)
	var impact_tween := create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(impact, "scale", Vector2.ONE * impact_scale, 0.10).set_delay(0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(impact, "modulate:a", 1.0, 0.04).set_delay(0.10)
	impact_tween.chain().tween_property(impact, "modulate:a", 0.0, 0.20).set_delay(0.10)
	impact_tween.chain().tween_callback(queue_free)


func _edge_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = EDGE_SHADER
	return result
