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
	configure_progression({"chapter_id": "chapter_01"}, {}, {})


func configure_progression(
	story_state: Dictionary,
	clear_counts: Dictionary,
	boss_defeated: Dictionary
) -> void:
	var chapter_id := String(story_state.get("chapter_id", "chapter_01"))
	var active_variants := _catalog.get_active_variant_ids(chapter_id)
	var pending_variant := _catalog.get_pending_boss_variant(
		chapter_id,
		clear_counts,
		boss_defeated
	)
	for slot_id in _catalog.get_portal_slot_ids():
		_configure_region_slot(
			slot_id,
			chapter_id,
			boss_defeated,
			pending_variant
		)
	_configure_boss_gate(active_variants, pending_variant)


func _configure_region_slot(
	slot_id: StringName,
	chapter_id: String,
	boss_defeated: Dictionary,
	pending_variant: StringName
) -> void:
	var portal := get_node("RegionPortals/%s" % SLOT_NODE_NAMES[slot_id])
	var label := get_node("PortalLabels/%s" % SLOT_LABEL_NAMES[slot_id]) as Label
	var variant_id := _catalog.get_variant_for_slot(chapter_id, slot_id)
	var glow := portal.get_node_or_null("ActiveGlow") as CanvasItem
	var seal := portal.get_node_or_null("Seal") as CanvasItem
	portal.set_meta("expedition_variant_id", variant_id)
	if variant_id.is_empty():
		portal.set("target_scene_path", "")
		portal.call("set_locked", true, "%s尚未在此篇章開放" % _slot_display_name(slot_id))
		label.text = "%s\n封印中" % _slot_display_name(slot_id)
		if glow != null:
			glow.visible = false
		if seal != null:
			seal.visible = true
		return
	var defeated := bool(boss_defeated.get(String(variant_id), false))
	portal.set("target_scene_path", _catalog.get_route_scene_path(variant_id))
	portal.call("set_locked", false, "")
	portal.set("prompt_text", "Enter %s" % _catalog.get_display_name(variant_id))
	label.text = "%s\n%s" % [
		_catalog.get_display_name(variant_id),
		(
			"Boss 已討伐"
			if defeated
			else (
				"強大的敵人正在靠近..."
				if not pending_variant.is_empty()
				else "可進入"
			)
		),
	]
	if glow != null:
		glow.visible = true
	if seal != null:
		seal.visible = false


func _configure_boss_gate(
	_active_variants: Array[StringName],
	pending_variant: StringName
) -> void:
	var boss_portal := $BossPortal
	var boss_label := $BossLabel as Label
	boss_portal.set_meta("expedition_variant_id", pending_variant)
	if pending_variant.is_empty():
		boss_portal.set("target_scene_path", "")
		boss_portal.call("set_locked", true, "中央封印尚未產生異動")
		boss_label.text = "中央 Boss 封印\n尚未感應到強敵"
		$BossPortal/ReadyGlow.visible = false
		$BossPortal/Seal.visible = true
	else:
		boss_portal.set("target_scene_path", _catalog.get_boss_scene_path(pending_variant))
		boss_portal.set("prompt_text", "觸發 %s Boss 戰" % _catalog.get_display_name(pending_variant))
		boss_portal.call("set_locked", false, "")
		boss_label.text = "%s Boss 門\n靠近並觸發以解除封印" % _catalog.get_display_name(pending_variant)
		$BossPortal/ReadyGlow.visible = true
		$BossPortal/Seal.visible = false


func _slot_display_name(slot_id: StringName) -> String:
	return {
		&"autumn": "秋季戰場",
		&"crystal": "水晶洞窟",
		&"hell": "地獄裂隙",
		&"heaven": "天堂聖域",
	}.get(slot_id, String(slot_id))
