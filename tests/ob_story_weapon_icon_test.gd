extends SceneTree

const CATALOG_PATH := "res://data/ob_story_weapon_icons.json"
const ATLAS_PATH := "res://assets/ui/story/generated/ob_story_weapon_icons.png"
const EXPECTED_IDS := [
	"watcher_holy_shield", "broken_wing_halberd", "seraph_core_spear",
	"moonless_bell", "phase_wrench", "zero_observation_lens",
	"myriad_soul_empty_sword", "uncrowned_ember_blade",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(ATLAS_PATH), "OB representative weapon icon atlas must exist.")
	_expect(FileAccess.file_exists(CATALOG_PATH), "OB representative weapon icon catalog must exist.")
	if FileAccess.file_exists(CATALOG_PATH):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH)) as Dictionary
		var entries := parsed.get("entries", []) as Array
		_expect(entries.size() == EXPECTED_IDS.size(), "OB icon catalog must contain eight representative story weapons.")
		var seen := {}
		for entry_variant in entries:
			var entry := entry_variant as Dictionary
			seen[String(entry.get("id", ""))] = true
			_expect(String(entry.get("source_document", "")).contains("裝備傳說與來歷.md"), "Every story icon must cite the OB authority.")
			var region := entry.get("atlas_region", []) as Array
			_expect(region.size() == 4 and int(region[2]) == 384 and int(region[3]) == 512, "Every story icon must own one 384x512 atlas cell.")
		for expected_id in EXPECTED_IDS:
			_expect(seen.has(expected_id), "Missing OB story weapon icon: %s." % expected_id)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
