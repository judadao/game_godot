class_name BattlePortalHub
extends Node2D

const CATALOG_SCRIPT := preload("res://scripts/systems/expedition_region_catalog.gd")
const SLOT_NODE_NAMES := {
	&"autumn": "AutumnPortal",
	&"crystal": "CrystalPortal",
	&"hell": "HellPortal",
	&"heaven": "HeavenPortal",
}
const SLOT_LABEL_NAMES := {
	&"autumn": "AutumnLabel",
	&"crystal": "CrystalLabel",
	&"hell": "HellLabel",
	&"heaven": "HeavenLabel",
}

var _catalog := CATALOG_SCRIPT.new()


func _ready() -> void:
	configure_progression({"chapter_id": "chapter_01"}, {}, {}, {}, {})


func configure_progression(
	story_state: Dictionary,
	clear_counts: Dictionary,
	fragment_counts: Dictionary,
	boss_keys: Dictionary,
	boss_defeated: Dictionary
) -> void:
	var chapter_id := String(story_state.get("chapter_id", "chapter_01"))
	var ready_boss_variants := _catalog.get_ready_boss_variants(
		chapter_id,
		boss_keys,
		boss_defeated
	)
	for slot_id in _catalog.get_portal_slot_ids():
		_configure_region_slot(
			slot_id,
			chapter_id,
			clear_counts,
			fragment_counts,
			boss_keys,
			boss_defeated,
		)
	_configure_boss_gate(ready_boss_variants, fragment_counts)


func _configure_region_slot(
	slot_id: StringName,
	chapter_id: String,
	_clear_counts: Dictionary,
	fragment_counts: Dictionary,
	boss_keys: Dictionary,
	boss_defeated: Dictionary
) -> void:
	var portal := get_node("RegionPortals/%s" % SLOT_NODE_NAMES[slot_id])
	var label := get_node("PortalLabels/%s" % SLOT_LABEL_NAMES[slot_id]) as Label
	var variant_ids := _catalog.get_slot_variant_ids(chapter_id, slot_id)
	var glow := portal.get_node_or_null("ActiveGlow") as CanvasItem
	var seal := portal.get_node_or_null("Seal") as CanvasItem
	var portal_visual := portal.get_node_or_null("PortalVisual")
	portal.set_meta("expedition_variant_options", [])
	if variant_ids.is_empty():
		portal.set_meta("expedition_variant_id", &"")
		portal.set("target_scene_path", "")
		portal.call("set_locked", true, "%s尚未在此篇章開放" % _slot_display_name(slot_id))
		label.text = "%s\n封印中" % _slot_display_name(slot_id)
		if glow != null:
			glow.visible = false
		if seal != null:
			seal.visible = true
		if portal_visual != null and portal_visual.has_method("set_sealed"):
			portal_visual.call("set_sealed", true)
		return
	var options: Array[Dictionary] = []
	var ready_key_count := 0
	for variant_id in variant_ids:
		var key_ready := bool(boss_keys.get(String(variant_id), false))
		if key_ready and not bool(boss_defeated.get(String(variant_id), false)):
			ready_key_count += 1
		options.append(_build_variant_option(
			variant_id,
			false,
			int(fragment_counts.get(String(variant_id), 0)),
			key_ready,
			bool(boss_defeated.get(String(variant_id), false))
		))
	var default_variant := variant_ids[0]
	portal.set_meta("expedition_variant_id", default_variant)
	portal.set_meta("expedition_variant_options", options)
	portal.set("target_scene_path", _catalog.get_route_scene_path(default_variant))
	portal.call("set_locked", false, "")
	portal.set("prompt_text", (
		"選擇%s世界" % _slot_display_name(slot_id)
		if options.size() > 1
		else "Enter %s" % _catalog.get_display_name(default_variant)
	))
	label.text = "%s\n%s" % [
		_slot_display_name(slot_id),
		(
			"可選 %d 種世界 · %d 把鑰匙" % [options.size(), ready_key_count]
			if options.size() > 1
			else "可進入"
		),
	]
	if glow != null:
		glow.visible = true
	if seal != null:
		seal.visible = false
	if portal_visual != null and portal_visual.has_method("set_sealed"):
		portal_visual.call("set_sealed", false)


func _configure_boss_gate(
	ready_variants: Array[StringName],
	fragment_counts: Dictionary
) -> void:
	var boss_portal := $BossPortal
	var boss_label := $BossLabel as Label
	boss_portal.set_meta("expedition_variant_options", [])
	if ready_variants.is_empty():
		boss_portal.set_meta("expedition_variant_id", &"")
		boss_portal.set("target_scene_path", "")
		boss_portal.call("set_locked", true, "中央封印尚未產生異動")
		boss_label.text = "中央 Boss 封印\n尚未感應到強敵"
		$BossPortal/ReadyGlow.visible = false
		$BossPortal/Seal.visible = true
		$BossPortal/PortalVisual.set_sealed(true)
	else:
		var options: Array[Dictionary] = []
		for variant_id in ready_variants:
			options.append(_build_variant_option(
				variant_id,
				true,
				int(fragment_counts.get(String(variant_id), 0)),
				true,
				false
			))
		var default_variant := ready_variants[0]
		boss_portal.set_meta("expedition_variant_id", default_variant)
		boss_portal.set_meta("expedition_variant_options", options)
		boss_portal.set("target_scene_path", _catalog.get_boss_scene_path(default_variant))
		boss_portal.set("prompt_text", (
			"選擇要開啟的 Boss 通道"
			if options.size() > 1
			else "觸發 %s Boss 戰" % _catalog.get_display_name(default_variant)
		))
		boss_portal.call("set_locked", false, "")
		boss_label.text = (
			"中央 Boss 通道\n已組成 %d 把通道鑰匙" % options.size()
			if options.size() > 1
			else "%s Boss 門\n通道鑰匙已完成" % _catalog.get_display_name(default_variant)
		)
		$BossPortal/ReadyGlow.visible = true
		$BossPortal/Seal.visible = false
		$BossPortal/PortalVisual.set_sealed(false)


func _build_variant_option(
	variant_id: StringName,
	is_boss: bool,
	fragment_count: int,
	key_ready: bool,
	boss_defeated: bool
) -> Dictionary:
	return {
		"variant_id": String(variant_id),
		"display_name": _catalog.get_display_name(variant_id),
		"fragment_name": _catalog.get_fragment_name(variant_id),
		"fragment_count": clampi(fragment_count, 0, _catalog.BOSS_UNLOCK_CLEAR_COUNT),
		"fragment_required": _catalog.BOSS_UNLOCK_CLEAR_COUNT,
		"key_ready": key_ready,
		"boss_defeated": boss_defeated,
		"power_tier": _catalog.get_power_tier(variant_id),
		"is_boss": is_boss,
		"target_scene_path": (
			_catalog.get_boss_scene_path(variant_id)
			if is_boss
			else _catalog.get_route_scene_path(variant_id)
		),
	}


func _slot_display_name(slot_id: StringName) -> String:
	return {
		&"autumn": "秋季戰場",
		&"crystal": "水晶洞窟",
		&"hell": "地獄裂隙",
		&"heaven": "天堂聖域",
	}.get(slot_id, String(slot_id))
