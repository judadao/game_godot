extends SceneTree

const EXPECTED_SERIES_NAMES := [
	"劍雨", "月輪", "羽毛", "古木", "巨石", "巨盾", "火焰",
	"雷電", "水流", "植物攻擊", "龍息", "朝陽生息", "同枝共生",
]
const EXPECTED_SKILL_NAMES := [
	"戰律希聲", "萬劍垂天", "驟雨繁音",
	"月輪垂光", "扶搖月輪", "月蝕重輪",
	"千羽相應", "希聲繁羽", "天羽萬象",
	"古根纏行", "年輪護生", "萬古森羅",
	"靜岳無移", "石環守一", "群岳歸一",
	"守一返照", "守一共脈", "天門不破",
	"流火照夜", "霜蘭流火", "天火燎原",
	"綿息雷音", "流火雷音", "九霄震律",
	"扶搖泉湧", "靈泉不窮", "滄海回瀾",
	"蘭芷成蝕", "荊庭穿心", "萬華噬野",
	"奧術吐息", "龍脈迴響", "萬象龍臨",
	"朝光載陽", "春庭載陽", "青庭長春",
	"春靈來復", "同枝共脈", "同脈來復",
]
const RETIRED_SKILL_IDS := [
	"iron_momentum", "ember_reprise", "battle_tempo", "grand_strategy",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := SkillRecipeManager.new()
	_expect(catalog.load_catalog("res://data/skills.json"), "The skill-series catalog must load.")
	var has_series_api := (
		catalog.has_method("get_all_series")
		and catalog.has_method("get_all_skills")
		and catalog.has_method("get_skill")
		and catalog.has_method("get_retired_skill_ids")
		and catalog.has_method("get_legacy_vfx_id")
	)
	_expect(has_series_api, "The catalog must expose series, skill, and retirement queries.")
	if not has_series_api:
		quit(1)
		return
	var series := catalog.call("get_all_series") as Array
	var skills := catalog.call("get_all_skills") as Array
	_expect(series.size() == 13, "The new catalog must contain exactly 13 skill series.")
	_expect(skills.size() == 39, "Every series must contribute basic, advanced, and master skills.")

	var actual_series_names: Array[String] = []
	var actual_skill_names: Array[String] = []
	var seen_ids: Dictionary = {}
	for series_variant in series:
		var series_entry := series_variant as Dictionary
		actual_series_names.append(String(series_entry.get("name", "")))
		var series_skills := series_entry.get("skills", []) as Array
		_expect(series_skills.size() == 3, "%s must contain three skill tiers." % series_entry.get("id", ""))
		for tier_index in 3:
			var skill := series_skills[tier_index] as Dictionary
			var skill_id := String(skill.get("id", ""))
			actual_skill_names.append(String(skill.get("name", "")))
			_expect(not skill_id.is_empty() and not seen_ids.has(skill_id), "Skill IDs must be stable and unique: %s." % skill_id)
			seen_ids[skill_id] = true
			_expect(int(skill.get("tier_rank", 0)) == tier_index + 1, "%s must preserve basic/advanced/master ordering." % skill_id)
			_expect(String(skill.get("tier", "")) == ["basic", "advanced", "master"][tier_index], "%s must use the canonical tier ID." % skill_id)
			_expect(not String(skill.get("positioning", "")).is_empty(), "%s needs a gameplay positioning statement." % skill_id)
			_expect((skill.get("animation_beats", []) as Array).size() >= 3, "%s needs an authored continuous animation sequence." % skill_id)
			_expect(not String(skill.get("legacy_vfx_id", "")).is_empty(), "%s needs one legacy recipe compatibility ID." % skill_id)
			_expect(String(skill.get("series_vfx_id", "")) == String(series_entry.get("id", "")), "%s must reuse its own series main-object profile." % skill_id)

	_expect(actual_series_names == EXPECTED_SERIES_NAMES, "Series names and order must match the approved design.")
	_expect(actual_skill_names == EXPECTED_SKILL_NAMES, "All 39 approved skill names must be authoritative.")
	for retired_id in RETIRED_SKILL_IDS:
		_expect(catalog.call("get_skill", retired_id).is_empty(), "Retired passive skill must not remain active: %s." % retired_id)
	_expect(catalog.call("get_retired_skill_ids") == RETIRED_SKILL_IDS, "The catalog must explicitly retire every old passive skill ID.")

	if _failures == 0:
		print("PASS: 13 skill series and 39 tiered skills")
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
