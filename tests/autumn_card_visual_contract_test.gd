extends SceneTree

const AUTUMN_HAND_PATH := "res://scenes/ui/autumn/AutumnCardHandUI.tscn"
const AUTUMN_HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"
const AUTUMN_CARD_PATH := "res://scenes/ui/autumn/AutumnBattleCard.tscn"
const AUTUMN_RENDERER_PATH := "res://scripts/ui/autumn/autumn_card_hand_ui.gd"
const TOWN_HAND_PATH := "res://scenes/ui/town/TownCardHandUI.tscn"
const TOWN_RENDERER_PATH := "res://scripts/ui/cards/card_hand_ui.gd"
const REQUIRED_CARD_NODES := [
	"CardContent/Shortcut",
	"CardContent/InkWash",
	"CardContent/CelestialHalo",
	"CardContent/HeaderBand",
	"CardContent/CardName",
	"CardContent/NameBand",
	"CardContent/CategoryBand",
	"CardContent/CardType",
	"CardContent/IconStage",
	"CardContent/IconStage/IconFrame",
	"CardContent/SpectralRavens",
	"CardContent/VinesSmoke",
	"CardContent/SunWave",
	"CardContent/TarotFrameOverlay",
	"CardContent/Level",
	"CardContent/TypeGem",
	"CardContent/CostRow/APSeal",
	"CardContent/CostRow/CostLabel",
	"CardContent/CostRow/CostValue",
	"LockBadge",
	"CastFeedback",
]
const VIEWPORTS := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(2864, 1080),
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(AUTUMN_CARD_PATH), "Autumn must provide a structured battle-card scene.")
	_expect(ResourceLoader.exists(AUTUMN_RENDERER_PATH), "Autumn must provide its own card-hand renderer.")
	if _failures > 0:
		quit(1)
		return

	var town := (load(TOWN_HAND_PATH) as PackedScene).instantiate() as Control
	_expect(
		String(town.get_script().resource_path) == TOWN_RENDERER_PATH,
		"Town hand must retain the shared CardHandUI renderer contract."
	)
	town.free()

	for viewport_size in VIEWPORTS:
		await _verify_viewport(viewport_size)

	if _failures == 0:
		print("PASS: Autumn structured card and layered-row visual contract")
	quit(1 if _failures > 0 else 0)


func _verify_viewport(viewport_size: Vector2i) -> void:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var packed_hud := load(AUTUMN_HUD_PATH) as PackedScene
	_expect(packed_hud != null, "Autumn HUD scene must load at %s." % viewport_size)
	if packed_hud == null:
		viewport.queue_free()
		return
	var hud := packed_hud.instantiate() as Control
	viewport.add_child(hud)
	var hand := hud.get_node(
		"BottomStage/CardStage/AutumnCardHandUI"
	) as CardHandUI
	_expect(hand != null, "Autumn hand renderer must parse and inherit CardHandUI at %s." % viewport_size)
	if hand == null:
		hud.free()
		viewport.queue_free()
		return
	hand.set_cards(_sample_cards(), 3.0)
	await process_frame
	await process_frame

	_expect(
		String(hand.get_script().resource_path) == AUTUMN_RENDERER_PATH,
		"Autumn hand must use its Autumn-only renderer at %s." % viewport_size
	)
	_expect(hand.get_card_button_count() == 4, "Autumn hand must show the four-card Combo/Healing hand at %s." % viewport_size)
	if hand.get_card_button_count() != 4:
		hand.queue_free()
		await process_frame
		return

	for index in 4:
		var card := hand.get_card_button(index)
		_expect(
			String(card.get_script().resource_path).ends_with("autumn_battle_card.gd"),
			"Card %d must use the structured Autumn card component at %s." % [index, viewport_size]
		)
		for node_path in REQUIRED_CARD_NODES:
			_expect(
				card.has_node(node_path),
				"Card %d must expose %s at %s." % [index, node_path, viewport_size]
			)
		_expect(card.has_method("is_fixed"), "Autumn card %d must expose lock-state projection." % index)
		if card.has_method("is_fixed"):
			_expect(
				bool(card.call("is_fixed")),
				"Every reusable hand slot must show fixed-card treatment at %s." % viewport_size
			)
			var lock_badge := card.get_node("LockBadge") as Control
			_expect(not lock_badge.visible, "The shared frame must carry fixed-card identity without a loose badge.")
		var slot := card.get_parent() as Control
		_expect(
			slot != null
				and absf(card.size.x - slot.size.x) <= 1.0
				and absf(card.size.y - slot.size.y) <= 1.0,
			"Card %d must stretch to fill its authored hand slot at %s; card=%s slot=%s." % [
				index,
				viewport_size,
				card.size,
				slot.size if slot != null else Vector2.ZERO,
			]
		)
		_expect(
			card.size.y >= 112.0,
			"Card %d must remain tall enough for readable 720p text at %s; got %.1fpx." % [
				index,
				viewport_size,
				card.size.y,
			]
		)
		var card_name := card.get_node("CardContent/CardName") as Label
		var role_label := card.get_node("CardContent/CardType") as Label
		var ink_wash := card.get_node("CardContent/InkWash") as ColorRect
		var icon := card.get_node("CardContent/IconStage/Icon") as TextureRect
		var shortcut := card.get_node("CardContent/Shortcut") as Label
		var header_band := card.get_node("CardContent/HeaderBand") as Panel
		var name_band := card.get_node("CardContent/NameBand") as Panel
		var tarot_overlay := card.get_node("CardContent/TarotFrameOverlay") as Control
		var halo_layer := card.get_node("CardContent/CelestialHalo") as TextureRect
		var raven_layer := card.get_node("CardContent/SpectralRavens") as TextureRect
		var vines_layer := card.get_node("CardContent/VinesSmoke") as TextureRect
		var sun_wave := card.get_node("CardContent/SunWave") as Control
		var stack_seal := card.get_node("CardContent/Level") as Label
		var type_gem := card.get_node("CardContent/TypeGem") as Label
		var cost_label := card.get_node("CardContent/CostRow/CostLabel") as Label
		var cost_row := card.get_node("CardContent/CostRow") as Control
		var cost_seal := card.get_node("CardContent/CostRow/APSeal") as Panel
		var cost_inner_ring := card.get_node("CardContent/CostRow/APInnerRing") as Panel
		var cost_value := card.get_node("CardContent/CostRow/CostValue") as Label
		_expect(
			shortcut.size.y >= 32.0
				and shortcut.size.y <= 36.0
				and shortcut.position.y >= card.size.y * 0.18
				and shortcut.get_theme_font_size("font_size") >= 18,
			"Q/W/E/R prompts must use a restrained inset key seal, not an oversized floating button."
		)
		_expect(
			not header_band.visible
				and _canvas_rect(tarot_overlay).encloses(_canvas_rect(shortcut))
				and shortcut.position.x + shortcut.size.x * 0.5 <= card.size.x * 0.24
				and shortcut.position.y + shortcut.size.y * 0.5 <= card.size.y * 0.34,
			"Shortcut seals must sit inside the tarot frame's upper-left medallion, not a table header."
		)
		var shortcut_style := shortcut.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(
			shortcut_style != null
				and shortcut_style.border_width_left == 2
				and shortcut_style.shadow_size <= 2
				and shortcut_style.corner_radius_top_left >= 18,
			"Shortcut must enlarge the tarot medallion into one integrated circular key seal."
		)
		var serif_font := card_name.get_theme_font("font") as SystemFont
		_expect(
			serif_font != null and serif_font.font_names.has("Noto Serif TC"),
			"Chinese card typography must use the approved Traditional Chinese serif stack."
		)
		_expect(
			shortcut.get_theme_font("font") == serif_font
				and role_label.get_theme_font("font") == serif_font
				and cost_label.get_theme_font("font") == serif_font
				and cost_value.get_theme_font("font") == serif_font,
			"Title, metadata, shortcut, and AP must share one deliberate serif typography family."
		)
		_expect(
			not role_label.text.contains("COMBO") and not role_label.text.contains("HEALING"),
			"Visible card metadata must use Chinese type names instead of mixed English labels."
		)
		_expect(
			role_label.get_theme_font_size("font_size") >= 12
				and role_label.size.x >= card.size.x * 0.60,
			"Chinese family/type metadata must remain wide and readable at %s." % viewport_size
		)
		_expect(
			card_name.get_theme_font_size("font_size") >= 12
				and name_band.visible,
			"Card %d name must retain a readable serif title after adaptive fitting at %s." % [index, viewport_size]
		)
		_expect(
			_canvas_rect(icon).end.y <= _canvas_rect(card_name).position.y + 0.5
				and _canvas_rect(tarot_overlay).encloses(_canvas_rect(card_name)),
			"Card %d artwork must end before the tarot frame's dedicated title cartouche at %s; art=%s title=%s."
				% [index, viewport_size, _canvas_rect(icon), _canvas_rect(card_name)]
		)
		_expect(
			card_name.autowrap_mode == TextServer.AUTOWRAP_ARBITRARY
				and card_name.max_lines_visible == 2
				and card_name.clip_text
				and card_name.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS
				and _canvas_rect(name_band).encloses(_canvas_rect(card_name))
				and not _canvas_rect(card_name).intersects(_canvas_rect(card.get_node("CardContent/CategoryBand") as Control))
				and not _canvas_rect(card_name).intersects(_canvas_rect(cost_row)),
			"Long Chinese skill names must fit a dedicated two-line ellipsized cartouche without touching type or AP at %s." % viewport_size
		)
		_expect(
			cost_row.size.x >= 34.0
				and cost_row.size.x <= 38.0
				and cost_row.size.y >= 34.0
				and cost_row.size.y <= 38.0
				and cost_row.position.y + cost_row.size.y * 0.5 >= card.size.y * 0.76
				and not cost_label.visible
				and cost_value.get_theme_font_size("font_size") >= 22
				and not cost_seal.visible
				and not cost_inner_ring.visible,
			"Card %d AP cost must reuse the tarot frame's large lower-right medallion without another box."
				% index
		)
		_expect(not stack_seal.visible, "Battle cards must omit permanent stack counts from the compact face.")
		_expect(
			type_gem.visible
				and not type_gem.text.is_empty()
				and not role_label.text.begins_with("◆")
				and type_gem.position.x + type_gem.size.x * 0.5 >= card.size.x * 0.72
				and type_gem.position.y + type_gem.size.y * 0.5 <= card.size.y * 0.38,
			"The family-colored type icon must occupy the upper-right medallion, outside the Chinese category label."
		)
		var category_style := (card.get_node("CardContent/CategoryBand") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		_expect(
			category_style != null
				and category_style.border_width_left == 1
				and category_style.border_width_top == 1
				and category_style.border_width_right == 1
				and category_style.border_width_bottom == 1
				and category_style.bg_color.a >= 0.80
				and _canvas_rect(card.get_node("CardContent/CategoryBand") as Control).encloses(_canvas_rect(role_label)),
			"Chinese category metadata must stay inside its warm-ink, four-sided gold cartouche."
		)
		_expect(
			cost_value.text.is_valid_int()
				and not cost_value.text.contains("AP")
				and cost_value.text.strip_edges() == cost_value.text,
			"The lower-right medallion must show only the numeric AP cost."
		)
		_expect(
			card.has_method("play_cast_feedback")
				and card.has_method("is_cast_feedback_active"),
			"Every Autumn card must expose short cast-feedback behavior."
		)
		_expect(
			card.has_method("get_frame_design_state"),
			"Every Autumn card must expose its code-native ritual-frame contract."
		)
		if card.has_method("get_frame_design_state"):
			var frame_state := card.call("get_frame_design_state") as Dictionary
			_expect(
				int(frame_state.get("frame_layers", 0)) == 4
					and not bool(frame_state.get("shared_frame_asset", true))
					and bool(frame_state.get("shared_frame_geometry", false))
					and bool(frame_state.get("code_native_geometry", false))
					and bool(frame_state.get("aligned_transparent_layers", false))
					and bool(frame_state.get("seven_by_eight", false))
					and bool(frame_state.get("name_plate", false))
					and bool(frame_state.get("full_artwork", false))
					and bool(frame_state.get("monochrome_gold", false)),
				"Card %d must use full artwork inside a monochrome-gold tarot frame." % index
			)
			_expect(
				bool(frame_state.get("organic_tarot_overlay", false))
					and bool(frame_state.get("no_table_grid", false))
					and bool(frame_state.get("category_tab", false))
					and not bool(frame_state.get("stack_seal", true))
					and bool(frame_state.get("type_gem", false))
					and not bool(frame_state.get("category_gem", true))
					and bool(frame_state.get("audio_wave_rays", false))
					and bool(frame_state.get("gold_charge_flow", false))
					and int(frame_state.get("motion_layers", 0)) >= 4,
				"Card %d must expose an organic tarot silhouette and layered motion contract." % index
			)
		_expect(card.has_method("get_motion_state"), "Tarot cards must expose idle motion state.")
		if card.has_method("get_motion_state"):
			var motion_state := card.call("get_motion_state") as Dictionary
			_expect(
				bool(motion_state.get("idle_breathing", false))
					and bool(motion_state.get("halo_breathing", false))
					and bool(motion_state.get("raven_drift", false))
					and bool(motion_state.get("vines_breathing", false))
					and bool(motion_state.get("sun_wave_visualizer", false))
					and bool(motion_state.get("gold_charge_flow", false))
					and bool(motion_state.get("frame_shimmer", false)),
				"Card %d must keep at least three restrained animated layers." % index
			)
		var normal_style := card.get_theme_stylebox("normal") as StyleBoxFlat
		var icon_style := (card.get_node(
			"CardContent/IconStage/IconFrame"
		) as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		_expect(
			normal_style != null
				and normal_style.border_width_left == 0
				and normal_style.shadow_size <= 2
				and icon_style != null
				and icon_style.border_width_left == 0,
			"Card %d must remove table-like rectangular framing behind the organic tarot overlay." % index
		)
		_expect(
			tarot_overlay.has_method("get_geometry_state")
				and bool((tarot_overlay.call("get_geometry_state") as Dictionary).get("code_native", false))
				and bool((tarot_overlay.call("get_geometry_state") as Dictionary).get("adjustable_arcs", false))
				and bool((tarot_overlay.call("get_geometry_state") as Dictionary).get("integrated_medallions", false))
				and bool((tarot_overlay.call("get_geometry_state") as Dictionary).get("global_timeline", false))
				and bool((tarot_overlay.call("get_geometry_state") as Dictionary).get("seamless_wrap", false)),
			"Card %d must use an adjustable code-native geometric tarot frame." % index
		)
		_expect(
			halo_layer.texture != null
				and raven_layer.texture != null
				and vines_layer.texture != null
				and halo_layer.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
				and raven_layer.expand_mode == TextureRect.EXPAND_IGNORE_SIZE
				and vines_layer.expand_mode == TextureRect.EXPAND_IGNORE_SIZE,
			"Card %d must align halo, ravens, and vines to the shared frame bounds." % index
		)
		var family := String(card.call("get_visual_family"))
		_expect(
			ink_wash.color.a <= 0.01
				and raven_layer.visible == (family == "VOLLEY")
				and vines_layer.visible == (family == "HEALING")
				and not halo_layer.visible
				and sun_wave.z_index < icon.get_parent().z_index
				and icon.material is ShaderMaterial,
			"Card %d must remove the halo, reveal the radial sunburst through keyed art, and reserve repeated ornaments for matching families."
				% index
		)
		_expect(
			sun_wave.has_method("get_visualizer_state")
				and int((sun_wave.call("get_visualizer_state") as Dictionary).get("ray_count", 0)) >= 48
				and int((sun_wave.call("get_visualizer_state") as Dictionary).get("ray_count", 0)) <= 72
				and bool((sun_wave.call("get_visualizer_state") as Dictionary).get("radial_360", false))
				and bool((sun_wave.call("get_visualizer_state") as Dictionary).get("sacred_geometry", false))
				and float((sun_wave.call("get_visualizer_state") as Dictionary).get("ray_width", 0.0)) >= 2.4
				and float((sun_wave.call("get_visualizer_state") as Dictionary).get("accent_ray_width", 0.0)) >= 3.8
				and bool((sun_wave.call("get_visualizer_state") as Dictionary).get("circular_envelope", false))
				and bool((sun_wave.call("get_visualizer_state") as Dictionary).get("global_timeline", false))
				and bool((sun_wave.call("get_visualizer_state") as Dictionary).get("seamless_wrap", false))
				and is_equal_approx(float((sun_wave.call("get_visualizer_state") as Dictionary).get("circularity", 0.0)), 1.0),
			"Card %d must combine a code-native flowing-gold frame with a thick circular sacred-geometry sunburst." % index
		)
		_expect(
			icon.visible
				and icon.texture != null
				and icon.size.x >= card.size.x * 0.60
				and icon.size.y >= card.size.y * 0.50,
			"Card %d artwork must dominate the tarot face instead of remaining a small icon at %s."
				% [index, viewport_size]
		)
		_expect(
			role_label.text.contains("連段") or role_label.text.contains("治療"),
			"Card %d must preserve its localized gameplay type beside the visual family at %s." % [index, viewport_size]
		)
		_expect(
			_contains_han(role_label.text),
			"Card %d information hierarchy must include an intuitive Chinese family label." % index
		)
		_expect(card.has_method("get_visual_family"), "Autumn cards must expose their visual family.")
		_expect(_inside_lower_hud(card, viewport_size), "Card %d must remain inside the lower HUD at %s." % [index, viewport_size])
		if index > 0:
			var previous := hand.get_card_button(index - 1) as Control
			_expect(
				not _canvas_rect(previous).intersects(_canvas_rect(card)),
				"Long Chinese names must not stretch adjacent card frames into overlap at %s." % viewport_size
			)
	var front_row := hand.get_node(
		"CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/FrontRow"
	) as HBoxContainer
	var back_row := hand.get_node(
		"CardSafeArea/BottomMargin/BottomRow/HandSlot/CardRows/BackRow"
	) as HBoxContainer
	var hand_slot := hand.get_node(
		"CardSafeArea/BottomMargin/BottomRow/HandSlot"
	) as Control
	_expect(
		not back_row.visible
			and absf(front_row.position.y - hand_slot.position.y) <= 1.0
			and absf(front_row.size.y - hand_slot.size.y) <= 1.0,
		"The unused back row must not reserve vertical space; the active hand must rise to fill "
			+ "the complete card stage at %s; front=%s slot=%s." % [
				viewport_size,
				Rect2(front_row.position, front_row.size),
				Rect2(hand_slot.position, hand_slot.size),
			]
	)
	var first_slot := front_row.get_child(0) as Control
	var last_slot := front_row.get_child(3) as Control
	var slot_span := last_slot.position.x + last_slot.size.x - first_slot.position.x
	_expect(
		absf(slot_span - front_row.size.x) <= 1.0,
		"Four authored slots must consume the full FrontRow width at %s; slots=%.1f row=%.1f."
			% [viewport_size, slot_span, front_row.size.x]
	)
	for index in 3:
		var current_slot := front_row.get_child(index) as Control
		var next_slot := front_row.get_child(index + 1) as Control
		_expect(
			absf(current_slot.size.x - next_slot.size.x) <= 1.0,
			"All four hand slots must remain equal-width at %s." % viewport_size
		)

	# A full-width card cannot grow horizontally on hover without invading its neighbour.
	hand.call("_set_card_hover", 1, true, false)
	for index in 3:
		_expect(
			not _canvas_rect(hand.get_card_button(index)).intersects(
				_canvas_rect(hand.get_card_button(index + 1))
			),
			"Hover feedback must not overlap adjacent full-width cards at %s." % viewport_size
		)
	hand.call("_set_card_hover", 1, false, false)
	if viewport_size.x >= 1920:
		var hand_rect := _canvas_rect(hand)
		var first_card_rect := _canvas_rect(hand.get_card_button(0))
		var last_card_rect := _canvas_rect(hand.get_card_button(3))
		var occupied_span := last_card_rect.end.x - first_card_rect.position.x
		_expect(
			occupied_span >= hand_rect.size.x * 0.98,
			"Four sword-soul slots must fill the wide hand region at %s; occupied %.1f of %.1f px."
				% [viewport_size, occupied_span, hand_rect.size.x]
		)
	var families: Array[String] = []
	for index in 4:
		families.append(String(hand.get_card_button(index).call("get_visual_family")))
	_expect(
		families == ["FLAME", "VOLLEY", "STORM", "HEALING"],
		"Fixed cards must use four instantly distinguishable visual families at %s." % viewport_size
	)
	_verify_group_states(hand, 0, viewport_size)
	for index in 4:
		_expect(
			int(hand.get_card_button(index).get_meta("global_card_index", -1)) == index,
			"Single-hand card %d must retain its direct index at %s." % [index, viewport_size]
		)

	hud.queue_free()
	viewport.queue_free()
	await process_frame


func _verify_group_states(hand: CardHandUI, active_group: int, viewport_size: Vector2i) -> void:
	for index in 4:
		var card := hand.get_card_button(index)
		_expect(card.mouse_filter == Control.MOUSE_FILTER_STOP, "Visible card %d must accept mouse input at %s." % [index, viewport_size])
		_expect(card.focus_mode == Control.FOCUS_ALL, "Visible card %d must accept focus at %s." % [index, viewport_size])
		_expect(card.modulate.get_luminance() > 0.85, "Visible card %d must remain bright at %s." % [index, viewport_size])
		_expect(card.z_index >= 100, "Visible card %d must render in the active layer at %s." % [index, viewport_size])
		_expect(
			int(card.get_meta("global_card_index", -1)) / 4 == active_group,
			"Visible card %d must belong to active group %d at %s." % [index, active_group, viewport_size]
		)


func _inside_lower_hud(card: Control, viewport_size: Vector2i) -> bool:
	var rect := _canvas_rect(card)
	var hud_top := float(viewport_size.y) * 0.66
	return (
		rect.position.x >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.position.y >= hud_top - 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _canvas_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _contains_han(text: String) -> bool:
	for character in text:
		var codepoint := character.unicode_at(0)
		if codepoint >= 0x3400 and codepoint <= 0x9FFF:
			return true
	return false


func _sample_cards() -> Array:
	return [
		{"id": "flame_imbue", "name": "煉獄業火萬象焚天劍魂灌注之式", "type": "combo", "description": "Add flame.", "cost": 3, "level": 1, "fixed": true, "combo_stack": 2},
		{"id": "echo_volley", "name": "無盡迴響千羽齊射破空追魂之式", "type": "combo", "description": "Add projectiles.", "cost": 2, "level": 1, "fixed": true, "combo_stack": 1},
		{"id": "storm_charge", "name": "天罰雷霆風暴萬鈞充能劍魂之式", "type": "combo", "description": "Add storm.", "cost": 3, "level": 1, "fixed": true, "combo_stack": 3},
		{"id": "healing_light", "name": "春庭朝光翠綠萬物復甦療癒之式", "type": "healing", "description": "Restore health.", "cost": 1, "level": 1, "fixed": true},
	]


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
