class_name BattleHubPortalVisual
extends Node2D

const TOWN_ART_BOTTOM_FROM_ORIGIN := 102.0

@export var accent := Color(0.95, 0.48, 0.18, 1.0):
	set(value):
		accent = value
		if is_node_ready():
			_apply_state()

@export var sealed := false:
	set(value):
		sealed = value
		if is_node_ready():
			_apply_state()

@export var visual_scale := Vector2(1.15, 0.88):
	set(value):
		visual_scale = value
		if is_node_ready():
			_apply_geometry()

@export var aperture_bottom_offset_y := -121.0:
	set(value):
		aperture_bottom_offset_y = value
		if is_node_ready():
			_apply_geometry()

@export var seal_detail_scale := Vector2.ONE:
	set(value):
		seal_detail_scale = value
		if is_node_ready():
			_apply_geometry()

@export var seal_detail_offset := Vector2.ZERO:
	set(value):
		seal_detail_offset = value
		if is_node_ready():
			_apply_geometry()

@export var show_seal_ring := true:
	set(value):
		show_seal_ring = value
		if is_node_ready():
			_apply_state()

@export var show_active_aura := true:
	set(value):
		show_active_aura = value
		if is_node_ready():
			_apply_state()

@export var show_portal_rune := true:
	set(value):
		show_portal_rune = value
		if is_node_ready():
			_apply_state()

@export_range(0.0, 1.0, 0.01) var seal_veil_alpha := 0.76:
	set(value):
		seal_veil_alpha = value
		if is_node_ready():
			_apply_state()


func _ready() -> void:
	_apply_geometry()
	_apply_state()


func set_sealed(value: bool) -> void:
	sealed = value


func _apply_geometry() -> void:
	var aperture_anchor := get_node_or_null("ApertureAnchor") as Node2D
	var portal_scale := get_node_or_null("ApertureAnchor/PortalScale") as Node2D
	var seal_rig := get_node_or_null("ApertureAnchor/PortalScale/SealRig") as Node2D
	if aperture_anchor != null:
		aperture_anchor.position = Vector2(
			0.0,
			aperture_bottom_offset_y - TOWN_ART_BOTTOM_FROM_ORIGIN * visual_scale.y
		)
	if portal_scale != null:
		portal_scale.scale = visual_scale
	if seal_rig != null:
		seal_rig.position = seal_detail_offset
		seal_rig.scale = seal_detail_scale


func _apply_state() -> void:
	var active_portal := get_node_or_null(
		"ApertureAnchor/PortalScale/ActivePortalAnimation"
	) as Node2D
	var sealed_portal := get_node_or_null(
		"ApertureAnchor/PortalScale/SealedPortalAnimation"
	) as Node2D
	var active_aura := get_node_or_null("ApertureAnchor/PortalScale/ActiveAura") as Line2D
	var seal_rig := get_node_or_null("ApertureAnchor/PortalScale/SealRig") as Node2D
	if active_portal != null:
		active_portal.visible = not sealed
		active_portal.modulate = Color(accent.r, accent.g, accent.b, 0.94)
		_set_portal_rune_visible(active_portal)
		_set_portal_motion(active_portal, not sealed)
	if sealed_portal != null:
		sealed_portal.visible = sealed
		sealed_portal.modulate = Color(
			lerpf(accent.r, 0.16, 0.72),
			lerpf(accent.g, 0.18, 0.72),
			lerpf(accent.b, 0.24, 0.68),
			0.58
		)
		_set_portal_rune_visible(sealed_portal)
		_set_portal_motion(sealed_portal, false)
	if active_aura != null:
		active_aura.visible = not sealed and show_active_aura
		active_aura.default_color = Color(accent.r, accent.g, accent.b, 0.72)
	if seal_rig != null:
		seal_rig.visible = sealed
		_apply_seal_palette(seal_rig)


func _set_portal_rune_visible(portal: Node2D) -> void:
	var rune := portal.get_node_or_null("PortalRuneGlow") as Polygon2D
	if rune != null:
		rune.visible = show_portal_rune


func _set_portal_motion(portal: Node2D, enabled: bool) -> void:
	for candidate in portal.find_children("*", "AnimatedSprite2D", true, false):
		var sprite := candidate as AnimatedSprite2D
		if enabled:
			sprite.speed_scale = 1.0
			sprite.play(&"vortex")
		else:
			sprite.stop()
			sprite.frame = 0
			sprite.frame_progress = 0.0
	var pulse := portal.get_node_or_null("PortalPulse") as AnimationPlayer
	if pulse == null:
		return
	if enabled:
		pulse.play(&"pulse")
	else:
		pulse.stop()
		pulse.seek(0.0, true)


func _apply_seal_palette(seal_rig: Node2D) -> void:
	var veil := seal_rig.get_node_or_null("SealVeil") as Polygon2D
	var ring := seal_rig.get_node_or_null("SealRing") as Line2D
	var glyph := seal_rig.get_node_or_null("SealGlyph") as Line2D
	var core := seal_rig.get_node_or_null("SealCore") as Polygon2D
	if veil != null:
		veil.color = Color(
			lerpf(accent.r, 0.035, 0.82),
			lerpf(accent.g, 0.045, 0.82),
			lerpf(accent.b, 0.08, 0.74),
			seal_veil_alpha
		)
	if ring != null:
		ring.visible = show_seal_ring
		ring.default_color = Color(accent.r, accent.g, accent.b, 0.72)
	if glyph != null:
		glyph.default_color = Color(
			lerpf(accent.r, 1.0, 0.32),
			lerpf(accent.g, 1.0, 0.32),
			lerpf(accent.b, 1.0, 0.32),
			0.9
		)
	if core != null:
		core.color = Color(accent.r, accent.g, accent.b, 0.46)
