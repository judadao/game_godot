extends SceneTree

const AUTUMN_HAND_PATH := "res://scenes/ui/autumn/AutumnCardHandUI.tscn"
const AUTUMN_HUD_PATH := "res://scenes/ui/autumn/AutumnHUD.tscn"
const AUTUMN_CARD_PATH := "res://scenes/ui/autumn/AutumnBattleCard.tscn"
const AUTUMN_RENDERER_PATH := "res://scripts/ui/autumn_card_hand_ui.gd"
const TOWN_HAND_PATH := "res://scenes/ui/CardHandUI.tscn"
const TOWN_RENDERER_PATH := "res://scripts/ui/card_hand_ui.gd"
const REQUIRED_CARD_NODES := [
	"CardContent/Shortcut",
	"CardContent/CardName",
	"CardContent/CardType",
	"CardContent/IconStage",
	"CardContent/Level",
	"CardContent/CostRow/CostLabel",
	"CardContent/CostRow/CostValue",
	"LockBadge",
]
const VIEWPORTS := [
	Vector2i(1152, 720),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
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
		"Town must keep the shared card-hand renderer."
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
	_expect(hand.get_card_button_count() == 8, "Autumn hand must show eight cards at %s." % viewport_size)
	if hand.get_card_button_count() != 8:
		hand.queue_free()
		await process_frame
		return

	for index in 8:
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
				not bool(card.call("is_fixed")),
				"No random-hand slot may show removed fixed-card treatment at %s." % viewport_size
			)
			var lock_badge := card.get_node("LockBadge") as Control
			_expect(not lock_badge.visible, "Random-hand cards must hide the old lock badge.")
		var aspect := card.size.x / maxf(1.0, card.size.y)
		_expect(
			aspect >= 0.68 and aspect <= 0.78,
			"Card %d must keep a tall 0.68-0.78 aspect ratio at %s; got %.3f." % [
				index,
				viewport_size,
				aspect,
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
		_expect(
			card_name.get_theme_font_size("font_size") >= 10,
			"Card %d name must use at least 10px text at %s." % [index, viewport_size]
		)
		_expect(_inside_lower_hud(card, viewport_size), "Card %d must remain inside the lower HUD at %s." % [index, viewport_size])
		if index == 6:
			var healing_style := card.get_theme_stylebox("normal") as StyleBoxFlat
			var healing_highlight := card.get_theme_stylebox("hover") as StyleBoxFlat
			_expect(
				healing_style != null
				and healing_style.bg_color.g > healing_style.bg_color.r
				and healing_style.bg_color.g > healing_style.bg_color.b,
				"Healing cards must use the approved green card body at %s." % viewport_size
			)
			_expect(
				healing_highlight != null and healing_highlight.border_color.g > 0.8,
				"Healing cards must use a brighter green border at %s." % viewport_size
			)

	_verify_group_states(hand, 0, viewport_size)
	hand.set_active_group(1)
	await process_frame
	await process_frame
	_verify_group_states(hand, 1, viewport_size)
	for index in 8:
		_expect(
			int(hand.get_card_button(index).get_meta("global_card_index", -1)) == index,
			"Group switching must preserve card %d's global index at %s." % [index, viewport_size]
		)

	hud.queue_free()
	viewport.queue_free()
	await process_frame


func _verify_group_states(hand: CardHandUI, active_group: int, viewport_size: Vector2i) -> void:
	for index in 8:
		var card := hand.get_card_button(index)
		var is_active := index / 4 == active_group
		if is_active:
			_expect(card.mouse_filter == Control.MOUSE_FILTER_STOP, "Active card %d must accept mouse input at %s." % [index, viewport_size])
			_expect(card.focus_mode == Control.FOCUS_ALL, "Active card %d must accept focus at %s." % [index, viewport_size])
			_expect(card.modulate.get_luminance() > 0.85, "Active card %d must remain bright at %s." % [index, viewport_size])
			_expect(card.z_index >= 100, "Active card %d must render above the inactive row at %s." % [index, viewport_size])
		else:
			_expect(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Inactive card %d must ignore mouse input at %s." % [index, viewport_size])
			_expect(card.focus_mode == Control.FOCUS_NONE, "Inactive card %d must not accept focus at %s." % [index, viewport_size])
			_expect(card.modulate.get_luminance() < 0.7, "Inactive card %d must be visibly recessed at %s." % [index, viewport_size])
			_expect(card.z_index < 100, "Inactive card %d must render behind the active row at %s." % [index, viewport_size])


func _inside_lower_hud(card: Control, viewport_size: Vector2i) -> bool:
	var rect := card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
	var hud_top := float(viewport_size.y) * 0.75
	return (
		rect.position.x >= -0.5
		and rect.end.x <= float(viewport_size.x) + 0.5
		and rect.position.y >= hud_top - 0.5
		and rect.end.y <= float(viewport_size.y) + 0.5
	)


func _sample_cards() -> Array:
	return [
		{"id": "ember_bolt", "name": "Ember Bolt", "type": "attack", "description": "Deal damage and burn.", "cost": 1, "level": 1},
		{"id": "quickstep", "name": "Quickstep", "type": "skill", "description": "Dash and evade.", "cost": 1, "level": 1},
		{"id": "frost_burst", "name": "Frost Burst", "type": "status", "description": "Add frost.", "cost": 1, "level": 1},
		{"id": "cleave", "name": "Cleave", "type": "attack", "description": "Arc strike.", "cost": 2, "level": 1},
		{"id": "blade_dance", "name": "Blade Dance", "type": "combo", "description": "Gain a timed effect.", "cost": 2, "level": 3},
		{"id": "gale_lunge", "name": "Gale Lunge", "type": "attack", "description": "Dash and strike.", "cost": 2, "level": 3},
		{"id": "healing_light", "name": "Healing Light", "type": "healing", "description": "Restore health immediately.", "cost": 2, "level": 1},
		{"id": "meteor", "name": "Meteor", "type": "ultimate", "description": "Devastating impact.", "cost": 5, "level": 1},
	]


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
