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
	_expect(
		catalog.get_slot_variant_ids("chapter_03", &"autumn") == [&"autumn", &"hell_autumn"]
			and catalog.get_slot_variant_ids("chapter_03", &"crystal") == [&"crystal", &"hell_crystal"]
			and catalog.get_slot_variant_ids("chapter_03", &"hell") == [&"hell"],
		"Hell unlock must add corrupted choices without replacing the normal Autumn and Crystal routes."
	)
	_expect(
		catalog.get_slot_variant_ids("chapter_04", &"autumn") == [&"autumn", &"hell_autumn", &"heaven_autumn"]
			and catalog.get_slot_variant_ids("chapter_04", &"crystal") == [&"crystal", &"hell_crystal", &"heaven_crystal"]
			and catalog.get_slot_variant_ids("chapter_04", &"hell") == [&"hell", &"disorder_hell"]
			and catalog.get_slot_variant_ids("chapter_04", &"heaven") == [&"heaven"],
		"Heaven unlock must retain normal and Hell choices while adding Heaven and Disorder variants."
	)
	_expect(
		catalog.get_power_tier(&"autumn") == 1
			and catalog.get_power_tier(&"crystal") == 2
			and catalog.get_power_tier(&"hell") == 3
			and catalog.get_power_tier(&"hell_autumn") == 3
			and catalog.get_power_tier(&"heaven") == 4
			and catalog.get_power_tier(&"heaven_autumn") == 4,
		"Expedition strength must strictly follow Autumn < Crystal < Hell < Heaven."
	)
	_expect(
		catalog.get_ready_boss_variants(
			"chapter_04",
			{"autumn": true, "hell_crystal": true, "disorder_hell": true},
			{}
		) == [&"autumn", &"hell_crystal", &"disorder_hell"],
		"Every assembled key must independently expose its matching Boss room."
	)

	for region_id in region_ids:
		_expect(meta.get_region_clear_count(region_id) == 0, "%s must begin at zero clears." % region_id)
		_expect(not meta.is_region_boss_ready(region_id), "%s boss must begin sealed." % region_id)
	for clear_index in 4:
		meta.record_region_clear(&"autumn")
		_expect(meta.get_region_clear_count(&"autumn") == clear_index + 1, "Every successful clear must increment exactly once.")
		_expect(
			meta.get_region_boss_fragment_count(&"autumn") == clear_index + 1,
			"Each Autumn clear must award exactly one Autumn fragment."
		)
	_expect(meta.is_region_boss_ready(&"autumn"), "Four clears must make the matching boss gate eligible.")
	_expect(meta.has_region_boss_key(&"autumn"), "Four Autumn fragments must assemble the Autumn Boss passage key.")
	for _clear_index in 4:
		meta.record_region_clear(&"crystal")
	_expect(
		meta.get_region_boss_fragment_count(&"crystal") == 4
			and meta.has_region_boss_key(&"crystal"),
		"Crystal clears must assemble a separate Crystal Boss passage key."
	)
	meta.mark_region_boss_defeated(&"autumn")
	_expect(meta.is_region_boss_defeated(&"autumn"), "Boss completion must be stored per region.")
	_expect(not meta.is_region_boss_ready(&"autumn"), "A defeated regional boss must not reopen as pending.")
	_expect(not meta.has_region_boss_key(&"autumn"), "Entering and clearing the Autumn Boss room must consume its key.")
	_expect(meta.has_region_boss_key(&"crystal"), "Consuming one Boss key must not affect another region's key.")

	var restored := MetaState.new()
	restored.apply_dict(meta.to_dict())
	_expect(restored.get_region_clear_count(&"autumn") == 4, "Region clear counts must survive save round trips.")
	_expect(restored.get_region_boss_fragment_count(&"crystal") == 4, "Boss fragments must survive save round trips.")
	_expect(restored.has_region_boss_key(&"crystal"), "Assembled Boss keys must survive save round trips.")
	_expect(restored.is_region_boss_defeated(&"autumn"), "Regional boss completion must survive save round trips.")
	_expect(int(restored.to_dict().get("schema_version", 0)) >= 11, "Fragment and key progress requires schema 11 or later.")

	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
