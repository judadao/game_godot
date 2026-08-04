extends SceneTree

const CATALOG_SCRIPT := preload("res://scripts/systems/expedition_region_catalog.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := CATALOG_SCRIPT.new()
	var meta := MetaState.new()
	var region_ids: Array[StringName] = catalog.get_variant_ids()
	_expect(
		catalog.get_portal_slot_ids() == [&"autumn", &"crystal", &"hell", &"heaven"],
		"The hub must retain four stable portal slots."
	)
	_expect(catalog.get_available_region_ids("chapter_01") == [&"autumn", &"crystal"], "Chapter 1 must open the first two regions.")
	_expect(catalog.get_available_region_ids("chapter_02") == [&"autumn", &"crystal"], "Chapter 2 must keep the first two regions open.")
	_expect(catalog.get_available_region_ids("chapter_03") == [&"hell_autumn", &"hell_crystal", &"hell"], "The Hell chapter must corrupt the first two regions and open Hell.")
	_expect(catalog.get_available_region_ids("chapter_04") == [&"heaven_autumn", &"heaven_crystal", &"disorder_hell", &"heaven"], "The Heaven chapter must sanctify the first two regions, turn Hell unordered, and open Heaven.")
	_expect(
		catalog.get_pending_boss_variant("chapter_03", {"hell_autumn": 4, "hell_crystal": 3}, {}) == &"hell_autumn",
		"The first undefeated active variant at four clears must own the pending central boss gate."
	)
	_expect(
		catalog.get_pending_boss_variant("chapter_03", {"hell_autumn": 4, "hell_crystal": 4}, {"hell_autumn": true}) == &"hell_crystal",
		"Defeating the pending boss must release the next eligible active variant."
	)

	for region_id in region_ids:
		_expect(meta.get_region_clear_count(region_id) == 0, "%s must begin at zero clears." % region_id)
		_expect(not meta.is_region_boss_ready(region_id), "%s boss must begin sealed." % region_id)
	for clear_index in 4:
		meta.record_region_clear(&"autumn")
		_expect(meta.get_region_clear_count(&"autumn") == clear_index + 1, "Every successful clear must increment exactly once.")
	_expect(meta.is_region_boss_ready(&"autumn"), "Four clears must make the matching boss gate eligible.")
	meta.mark_region_boss_defeated(&"autumn")
	_expect(meta.is_region_boss_defeated(&"autumn"), "Boss completion must be stored per region.")
	_expect(not meta.is_region_boss_ready(&"autumn"), "A defeated regional boss must not reopen as pending.")

	var restored := MetaState.new()
	restored.apply_dict(meta.to_dict())
	_expect(restored.get_region_clear_count(&"autumn") == 4, "Region clear counts must survive save round trips.")
	_expect(restored.is_region_boss_defeated(&"autumn"), "Regional boss completion must survive save round trips.")
	_expect(int(restored.to_dict().get("schema_version", 0)) >= 10, "Expedition progress requires schema 10 or later.")

	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
