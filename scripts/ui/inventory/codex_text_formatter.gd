class_name CodexTextFormatter
extends RefCounted


static func card_effect_summary(effect: Dictionary) -> String:
	var parts: Array[String] = []
	var effect_kind := String(effect.get("kind", ""))
	if effect.has("amount"):
		var amount_label := "效果"
		if effect_kind in ["heal", "regeneration"]:
			amount_label = "生命"
		elif effect_kind in ["gain_energy", "action_points"]:
			amount_label = "AP"
		elif effect_kind in ["damage", "area_damage", "damage_bonus"]:
			amount_label = "傷害"
		parts.append("%s %d" % [amount_label, int(effect["amount"])])
	if effect.has("heal"):
		parts.append("每次恢復 %d 生命" % int(effect["heal"]))
	if effect.has("pulses"):
		parts.append("生效 %d 次" % int(effect["pulses"]))
	if effect.has("interval"):
		parts.append("間隔 %.1f 秒" % float(effect["interval"]))
	if effect.has("damage_bonus"):
		parts.append("攻擊傷害 +%d" % int(effect["damage_bonus"]))
	if effect.has("radius"):
		parts.append("範圍 %d" % int(effect["radius"]))
	if effect.has("burn_damage"):
		parts.append("燃燒傷害 %d" % int(effect["burn_damage"]))
	if effect.has("frost_ratio"):
		parts.append("緩速 %d%%" % roundi(float(effect["frost_ratio"]) * 100.0))
	if effect.has("duration"):
		parts.append("持續 %.1f 秒" % float(effect["duration"]))
	if effect.has("status_id"):
		parts.append(status_display_name(String(effect["status_id"])))
	for status_variant in effect.get("statuses", []) as Array:
		var status := status_variant as Dictionary
		var status_parts: Array[String] = [
			status_display_name(String(status.get("status_id", "status")))
		]
		if status.has("tier"):
			status_parts.append("階級 %d" % int(status["tier"]))
		if status.has("ratio"):
			status_parts.append("%d%%" % roundi(float(status["ratio"]) * 100.0))
		if status.has("amount"):
			status_parts.append("效果 %d" % int(status["amount"]))
		if status.has("duration"):
			status_parts.append("%.1f 秒" % float(status["duration"]))
		parts.append(" ".join(status_parts))
	if effect.has("projectile_bonus"):
		parts.append("劍氣波 +%d" % int(effect["projectile_bonus"]))
	if effect.has("spread_degrees"):
		parts.append("散射角度 %.0f 度" % float(effect["spread_degrees"]))
	if effect.has("combo_stun"):
		parts.append("暈眩 %.2f 秒" % float(effect["combo_stun"]))
	if effect.has("size_multiplier"):
		parts.append("效果尺寸 ×%.2f" % float(effect["size_multiplier"]))
	if effect.has("attack_range_bonus"):
		parts.append("攻擊範圍 +%d" % roundi(float(effect["attack_range_bonus"])))
	if effect.has("attack_interval_multiplier"):
		parts.append("攻擊速度 +%d%%" % roundi((1.0 - float(effect["attack_interval_multiplier"])) * 100.0))
	if effect.has("projectile_speed_multiplier"):
		parts.append("彈體速度 +%d%%" % roundi((float(effect["projectile_speed_multiplier"]) - 1.0) * 100.0))
	if effect.has("attack_size_multiplier"):
		parts.append("攻擊尺寸 +%d%%" % roundi((float(effect["attack_size_multiplier"]) - 1.0) * 100.0))
	if effect.has("defense_bonus"):
		parts.append("防禦 +%d" % int(effect["defense_bonus"]))
	if effect.has("move_speed_multiplier"):
		parts.append("移動速度 +%d%%" % roundi(float(effect["move_speed_multiplier"]) * 100.0))
	if effect.has("ap_regen_bonus"):
		parts.append("AP 回復 +%.2f" % float(effect["ap_regen_bonus"]))
	if effect.has("ap_max_bonus"):
		parts.append("AP 上限 +%.0f" % float(effect["ap_max_bonus"]))
	if effect.has("poison_damage"):
		parts.append("中毒傷害 %d" % int(effect["poison_damage"]))
	if effect.has("poison_duration"):
		parts.append("中毒持續 %.1f 秒" % float(effect["poison_duration"]))
	if effect.has("critical_chance"):
		parts.append("暴擊率 +%d%%" % roundi(float(effect["critical_chance"]) * 100.0))
	if effect.has("critical_multiplier"):
		parts.append("暴擊傷害 ×%.2f" % float(effect["critical_multiplier"]))
	if effect.has("lifesteal_ratio"):
		parts.append("生命竊取 %d%%" % roundi(float(effect["lifesteal_ratio"]) * 100.0))
	if effect.has("combo_duration"):
		parts.append("附魔 %.1f 秒" % float(effect["combo_duration"]))
	return "、".join(parts) if not parts.is_empty() else effect_kind_display_name(effect_kind)


static func status_display_name(status_id: String) -> String:
	return {
		"super_armor": "霸體",
		"damage_reduction": "傷害減免",
		"regeneration": "持續恢復",
		"lifesteal": "生命竊取",
		"stun": "暈眩",
		"slow": "緩速",
	}.get(status_id, "特殊狀態")


static func effect_kind_display_name(effect_kind: String) -> String:
	return {
		"damage": "造成傷害",
		"area_damage": "造成範圍傷害",
		"heal": "恢復生命",
		"healing_pulses": "持續恢復生命",
		"regeneration": "持續恢復",
		"gain_energy": "恢復 AP",
		"action_points": "調整 AP",
		"combat_status": "獲得戰鬥狀態",
		"infusion": "獲得附魔",
	}.get(effect_kind, "依招式內容動態計算")


static func element_display_name(element: String) -> String:
	return {
		"water": "水",
		"fire": "火",
		"wind": "風",
		"lightning": "雷",
		"ice": "冰",
		"poison": "毒",
		"light": "光",
		"dark": "暗",
		"normal": "普通",
	}.get(element, "")


static func skill_recipe_description(recipe: Dictionary) -> String:
	return "已學會的招式，佔用 %d 點記憶容量；在戰鬥中完成條件後自動發動。" % int(recipe.get("memory_cost", 0))
