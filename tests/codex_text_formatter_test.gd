extends SceneTree

const CODEX_TEXT_FORMATTER := preload("res://scripts/ui/inventory/codex_text_formatter.gd")

var _failures := 0


func _init() -> void:
	_expect(CODEX_TEXT_FORMATTER.element_display_name("lightning") == "雷", "Element labels must preserve the current codex vocabulary.")
	_expect(CODEX_TEXT_FORMATTER.status_display_name("super_armor") == "霸體", "Status labels must preserve the current codex vocabulary.")
	_expect(CODEX_TEXT_FORMATTER.effect_kind_display_name("heal") == "恢復生命", "Effect-kind fallbacks must remain readable.")
	var summary := CODEX_TEXT_FORMATTER.card_effect_summary({
		"kind": "damage",
		"amount": 18,
		"burn_damage": 4,
		"duration": 1.5,
	})
	_expect(summary == "傷害 18、燃燒傷害 4、持續 1.5 秒", "Effect summary ordering and formatting must remain stable.")
	_expect(CODEX_TEXT_FORMATTER.skill_recipe_description({"memory_cost": 3}).contains("3 點記憶容量"), "Skill recipe description must project memory cost.")
	if _failures == 0:
		print("PASS: codex text projection is isolated from Game orchestration")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
