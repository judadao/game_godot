class_name NamedSkillVFXCatalog
extends RefCounted

const DEFAULT_DATA_PATH := "res://data/named_skill_vfx_profiles.json"
const FINISHER_DATA_PATH := "res://data/combo_finishers.json"
const FINISHER_IDENTITY_PATH := "res://data/finisher_vfx_identities.json"
const FINISHER_MATERIAL_ROOT := "res://assets/generated/vfx/finishers_v2"
const ELEMENT_TAXONOMY_SCRIPT := preload("res://scripts/systems/element_taxonomy.gd")
const FINISHER_LAYER_STACK := [
	"environment_surface",
	"semantic_underlay",
	"motion_echo",
	"semantic_body",
	"semantic_edge",
	"impact_surface",
	"physical_residue",
	"source_fragments",
	"contact_fragments",
	"residue_fragments",
]
const FINISHER_BATCH_A_IDS := [
	"silent_battle_rhythm", "horizon_stream", "sudden_rain_cadence", "falling_moon_arc",
	"thousand_blade_kill", "still_mountain", "stone_ring_guard", "tempered_bones",
	"trackless_gale", "enduring_arcane_breath", "inexhaustible_reservoir",
]
const FINISHER_BATCH_B_IDS := [
	"returning_counterguard", "inferno_cremation", "frozen_burial", "thunder_prison_pierce",
	"orchid_corrosion", "sunbearing_dawn", "returning_spring_spirits", "shared_bloodline",
	"evergreen_court", "silent_feather_cadence", "skyward_returning_feathers",
]
const FINISHER_SEMANTIC_OBJECTS := {
	"silent_battle_rhythm": "three forged blade ribs",
	"horizon_stream": "horizon plasma cut and reverse crescent",
	"sudden_rain_cadence": "staggered blue-steel rain blades",
	"falling_moon_arc": "cratered moonstone crescent guillotine",
	"thousand_blade_kill": "returning forged blade-feathers",
	"still_mountain": "immovable black slate mountain",
	"stone_ring_guard": "irregular basalt guard blocks",
	"tempered_bones": "forged ribcage becoming a knuckle fist",
	"trackless_gale": "three compressed-air lanes becoming wind blades",
	"enduring_arcane_breath": "reverse-flow mana double helix and pearl",
	"inexhaustible_reservoir": "living wellspring basin and water shield",
	"returning_counterguard": "stone guardian slab and returning wedges",
	"inferno_cremation": "molten river rising into a cremation blade",
	"frozen_burial": "faceted ice coffin under pressure",
	"thunder_prison_pierce": "lightning prison pillars collapsing into a spear",
	"orchid_corrosion": "toxic wax orchid with poison and healing dew",
	"sunbearing_dawn": "dawn leaf cup, shield leaves, and revival seed",
	"returning_spring_spirits": "water leaf and seed spirits forming a healing flower",
	"shared_bloodline": "living root and blood-channel life network",
	"evergreen_court": "moss basin, trunk, shield leaves, and blade leaves",
	"silent_feather_cadence": "staggered rust ivory and gold feather blades",
	"skyward_returning_feathers": "giant feather crescent with returning blades",
	"guarding_reflection": "four slanted mirror shields recording reflected attacks",
	"gale_reservoir": "braided wind-water trails and AP crystals",
	"balanced_elements": "water and flame walls split by lightning",
	"heavenly_wheel_sever": "three-layer fire feather and lightning cutting wheel",
	"frost_orchid_flame": "toxin-filled ice orchid split by a fire blade",
	"sunlit_spring_court": "vine garden arch, spring basin, and sun canopy",
	"returning_shared_pulse": "three blood lifelines and a targeted healing spirit core",
	"guarding_shared_pulse": "anchored channelled shield and opposite healing pulse",
	"gale_moon_arc": "broken wind-cut track and launched moon blade",
	"breathing_thunder_echo": "branching AP meridian with four echo lightning markers",
}
const VALID_FINISHER_ORIENTATIONS := [
	"forward", "horizontal", "descending", "rainy", "radial", "grounded",
	"vertical", "inward", "upward", "returning", "orbiting", "linked",
]
const VALID_ARCHETYPES := [
	"blade_storm_lane",
	"compression_detonation",
	"rail_prison",
	"orbiting_wheel",
	"descending_tomb",
	"armor_lock",
	"returning_arc",
	"rhythm_pulse",
	"tactical_ward",
]
const REQUIRED_KEYS := [
	"id",
	"display_name",
	"kind",
	"element",
	"archetype",
	"beat_pattern",
	"evolution_layers",
	"stack_milestones",
	"stack_traits",
	"atlas_path",
	"rows",
	"columns",
	"row",
	"region_y",
	"motion",
	"duration",
	"anticipation_time",
	"impact_time",
	"source",
	"target",
	"scale",
	"preview_scale",
	"shake_strength",
	"hit_stop",
]

var _profiles: Dictionary = {}
var _element_taxonomy: RefCounted = ELEMENT_TAXONOMY_SCRIPT.new()


func load_catalog(path: String = DEFAULT_DATA_PATH) -> bool:
	_profiles.clear()
	var parsed: Variant = _load_json_dictionary(path)
	if not parsed is Dictionary:
		push_error("Named skill VFX catalog root must be a Dictionary.")
		return false
	var profile_variants := (parsed as Dictionary).get("profiles", []) as Array
	if path == DEFAULT_DATA_PATH:
		profile_variants = _build_runtime_profiles(profile_variants)
		if profile_variants.is_empty():
			return false
	var rows_by_atlas: Dictionary = {}
	var archetypes: Dictionary = {}
	for profile_variant in profile_variants:
		if not profile_variant is Dictionary:
			push_error("Named skill VFX profiles must be dictionaries.")
			_profiles.clear()
			return false
		var profile := (profile_variant as Dictionary).duplicate(true)
		if not _validate_profile(profile, rows_by_atlas, archetypes):
			_profiles.clear()
			return false
		_profiles[String(profile["id"])] = profile
	return not _profiles.is_empty()


func _load_json_dictionary(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Named skill VFX data not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Named skill VFX data could not be opened: %s" % path)
		return null
	return JSON.parse_string(file.get_as_text())


func _build_runtime_profiles(authored_variants: Array) -> Array:
	var authored_by_id: Dictionary = {}
	var trigger_profiles: Array = []
	for profile_variant in authored_variants:
		if not profile_variant is Dictionary:
			continue
		var profile := (profile_variant as Dictionary).duplicate(true)
		var profile_id := String(profile.get("id", ""))
		authored_by_id[profile_id] = profile
		if String(profile.get("kind", "")) != "finisher":
			trigger_profiles.append(profile)
	var finisher_root: Variant = _load_json_dictionary(FINISHER_DATA_PATH)
	var identity_root: Variant = _load_json_dictionary(FINISHER_IDENTITY_PATH)
	if not finisher_root is Dictionary or not identity_root is Dictionary:
		return []
	var choreography_by_id := (identity_root as Dictionary).get("choreography_profiles", {}) as Dictionary
	var identities_by_id: Dictionary = {}
	for identity_variant in (identity_root as Dictionary).get("finishers", []) as Array:
		if not identity_variant is Dictionary:
			continue
		var identity := identity_variant as Dictionary
		identities_by_id[String(identity.get("id", ""))] = identity
	var runtime_profiles: Array = []
	for recipe_variant in (finisher_root as Dictionary).get("recipes", []) as Array:
		if not recipe_variant is Dictionary:
			continue
		var recipe := recipe_variant as Dictionary
		var finisher_id := String(recipe.get("id", ""))
		var identity := identities_by_id.get(finisher_id, {}) as Dictionary
		if identity.is_empty():
			push_error("Finisher VFX identity is missing: %s" % finisher_id)
			return []
		var choreography := choreography_by_id.get(finisher_id, {}) as Dictionary
		if choreography.is_empty():
			push_error("Finisher VFX choreography profile is missing: %s" % finisher_id)
			return []
		var has_authored_profile := authored_by_id.has(finisher_id)
		var base_id := String(identity.get("base_profile", finisher_id))
		var base_profile := (
			authored_by_id.get(finisher_id, {})
			if has_authored_profile
			else authored_by_id.get(base_id, {})
		) as Dictionary
		if base_profile.is_empty():
			push_error("Finisher VFX base profile is missing: %s -> %s" % [finisher_id, base_id])
			return []
		var profile := base_profile.duplicate(true)
		profile["id"] = finisher_id
		profile["display_name"] = String(recipe.get("name", finisher_id))
		profile["kind"] = "finisher"
		profile["element"] = String(identity.get("element", profile.get("element", "normal")))
		profile["role"] = String(recipe.get("role", "offense"))
		profile["icon_path"] = String(recipe.get("icon_path", ""))
		profile["beat_pattern"] = (identity.get("beat_pattern", profile.get("beat_pattern", [])) as Array).duplicate()
		profile["cadence"] = String(identity.get("cadence", "cinematic_three_beat"))
		profile["geometry_identity"] = (identity.get("geometry_identity", {}) as Dictionary).duplicate(true)
		profile["choreography"] = choreography.duplicate(true)
		var geometry_identity := profile["geometry_identity"] as Dictionary
		geometry_identity["choreography_family"] = String(choreography.get("family", ""))
		geometry_identity["spawn_primitives"] = (choreography.get("spawn_primitives", []) as Array).duplicate()
		geometry_identity["piece_count"] = (choreography.get("piece_count", {}) as Dictionary).duplicate(true)
		geometry_identity["formation"] = String(choreography.get("formation", ""))
		geometry_identity["travel_paths"] = (choreography.get("paths", []) as Array).duplicate()
		geometry_identity["impact_mode"] = String(choreography.get("impact", ""))
		geometry_identity["residue_mode"] = String(choreography.get("residue", ""))
		profile["particle_identity"] = (identity.get("particle_identity", {}) as Dictionary).duplicate(true)
		profile["light_identity"] = (identity.get("light_identity", {}) as Dictionary).duplicate(true)
		profile["presentation_mode"] = "2_5d"
		profile["material_path"] = "%s/%s_material.png" % [FINISHER_MATERIAL_ROOT, finisher_id]
		profile["storyboard_path"] = (
			"res://docs/art_concepts/finisher_choreography/batch_a.md"
			if FINISHER_BATCH_A_IDS.has(finisher_id)
			else "res://docs/art_concepts/finisher_choreography/batch_b.md"
			if FINISHER_BATCH_B_IDS.has(finisher_id)
			else "res://docs/art_concepts/finisher_choreography/batch_c.md"
		)
		profile["semantic_object"] = String(FINISHER_SEMANTIC_OBJECTS.get(finisher_id, finisher_id))
		var light_identity := profile["light_identity"] as Dictionary
		var visual_palette := (light_identity.get("palette", []) as Array).duplicate()
		(profile["geometry_identity"] as Dictionary)["palette"] = visual_palette.duplicate()
		(profile["particle_identity"] as Dictionary)["palette"] = visual_palette.duplicate()
		light_identity["energy"] = float(light_identity.get("energy", light_identity.get("bloom", 1.0)))
		profile["layer_stack"] = FINISHER_LAYER_STACK.duplicate()
		profile["identity_seed"] = absi(finisher_id.hash())
		profile["_shared_base_parts"] = not has_authored_profile
		runtime_profiles.append(profile)
	for trigger_variant in trigger_profiles:
		runtime_profiles.append((trigger_variant as Dictionary).duplicate(true))
	return runtime_profiles


func has_profile(profile_id: String) -> bool:
	return _profiles.has(profile_id)


func get_profile(profile_id: String) -> Dictionary:
	return (_profiles.get(profile_id, {}) as Dictionary).duplicate(true)


func get_all_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for profile_variant in _profiles.values():
		result.append((profile_variant as Dictionary).duplicate(true))
	result.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left.get("id", "")) < String(right.get("id", ""))
	)
	return result


func _validate_profile(
	profile: Dictionary,
	rows_by_atlas: Dictionary,
	archetypes: Dictionary
) -> bool:
	for key in REQUIRED_KEYS:
		if not profile.has(key):
			push_error("Named skill VFX profile is missing '%s'." % key)
			return false
	var profile_id := String(profile.get("id", "")).strip_edges()
	var element := String(profile.get("element", "")).strip_edges()
	var archetype := String(profile.get("archetype", "")).strip_edges()
	var atlas_path := String(profile.get("atlas_path", "")).strip_edges()
	var rows := int(profile.get("rows", 0))
	var columns := int(profile.get("columns", 0))
	var row := int(profile.get("row", -1))
	var shares_base_parts := bool(profile.get("_shared_base_parts", false))
	if profile_id.is_empty() or _profiles.has(profile_id):
		push_error("Named skill VFX id must be non-empty and unique: %s" % profile_id)
		return false
	if not bool(_element_taxonomy.call("is_valid", element)):
		push_error("Named skill VFX profile has an invalid element: %s" % profile_id)
		return false
	if archetype not in VALID_ARCHETYPES or (not shares_base_parts and archetypes.has(archetype)):
		push_error("Named skill VFX archetype must be supported and authored profiles must be unique: %s" % profile_id)
		return false
	if String(profile.get("kind", "")) == "finisher" and not _validate_finisher_identity(profile):
		return false
	if not _validate_beat_pattern(profile_id, profile.get("beat_pattern", null)):
		return false
	if not _validate_string_sequence(
		profile_id,
		"evolution_layers",
		profile.get("evolution_layers", null),
		3
	):
		return false
	if not _validate_stack_progression(profile_id, profile):
		return false
	if not FileAccess.file_exists(atlas_path):
		push_error("Named skill VFX atlas does not exist: %s" % atlas_path)
		return false
	if rows <= 0 or columns != 5 or row < 0 or row >= rows:
		push_error("Named skill VFX profile has an invalid atlas grid: %s" % profile_id)
		return false
	var region_y := profile.get("region_y", []) as Array
	if region_y.size() != 2 or int(region_y[0]) < 0 or int(region_y[1]) <= int(region_y[0]):
		push_error("Named skill VFX profile has an invalid vertical crop: %s" % profile_id)
		return false
	if not profile.get("source", []) is Array or (profile.get("source", []) as Array).size() != 2:
		push_error("Named skill VFX source must be a two-value array: %s" % profile_id)
		return false
	if not profile.get("target", []) is Array or (profile.get("target", []) as Array).size() != 2:
		push_error("Named skill VFX target must be a two-value array: %s" % profile_id)
		return false
	var anticipation := float(profile.get("anticipation_time", 0.0))
	var impact := float(profile.get("impact_time", 0.0))
	var duration := float(profile.get("duration", 0.0))
	if anticipation <= 0.0 or impact <= anticipation or duration <= impact:
		push_error("Named skill VFX timing is invalid: %s" % profile_id)
		return false
	var row_key := "%s:%d" % [atlas_path, row]
	if not shares_base_parts and rows_by_atlas.has(row_key):
		push_error("Named skill VFX atlas rows must be unique: %s" % row_key)
		return false
	if not shares_base_parts:
		rows_by_atlas[row_key] = profile_id
		archetypes[archetype] = profile_id
	return true


func _validate_finisher_identity(profile: Dictionary) -> bool:
	var profile_id := String(profile.get("id", ""))
	if String(profile.get("presentation_mode", "")) != "2_5d":
		push_error("Finisher VFX must use the shared 2.5D presentation mode: %s" % profile_id)
		return false
	var icon_path := String(profile.get("icon_path", ""))
	if String(profile.get("role", "")).is_empty() or not FileAccess.file_exists(icon_path):
		push_error("Finisher VFX must preserve its role and generated icon: %s" % profile_id)
		return false
	var material_path := String(profile.get("material_path", ""))
	var storyboard_path := String(profile.get("storyboard_path", ""))
	if material_path.is_empty() or not FileAccess.file_exists(material_path):
		push_error("Finisher VFX needs its authored semantic material: %s" % profile_id)
		return false
	# Markdown is a source-review authority and may be excluded from exported PCKs.
	# Keep the stable reference in runtime data; source tests verify that it exists.
	if storyboard_path.is_empty():
		push_error("Finisher VFX needs its choreography storyboard: %s" % profile_id)
		return false
	if String(profile.get("semantic_object", "")).strip_edges().is_empty():
		push_error("Finisher VFX needs a concrete semantic object: %s" % profile_id)
		return false
	var choreography := profile.get("choreography", {}) as Dictionary
	for choreography_key in ["family", "spawn_primitives", "piece_count", "formation", "paths", "impact", "residue"]:
		if not choreography.has(choreography_key):
			push_error("Finisher VFX choreography is missing '%s': %s" % [choreography_key, profile_id])
			return false
	if String(choreography.get("family", "")).strip_edges().is_empty():
		push_error("Finisher VFX choreography family must be concrete: %s" % profile_id)
		return false
	if (choreography.get("spawn_primitives", []) as Array).size() < 2:
		push_error("Finisher VFX choreography must assemble multiple semantic primitives: %s" % profile_id)
		return false
	if (choreography.get("piece_count", {}) as Dictionary).is_empty() or (choreography.get("paths", []) as Array).size() < 2:
		push_error("Finisher VFX choreography needs multiple pieces and a continuous path: %s" % profile_id)
		return false
	for identity_key in ["geometry_identity", "particle_identity", "light_identity"]:
		var identity := profile.get(identity_key, {}) as Dictionary
		if String(identity.get("motif", "")).is_empty():
			push_error("Finisher VFX %s needs a non-empty motif: %s" % [identity_key, profile_id])
			return false
	var orientation := String((profile.get("geometry_identity", {}) as Dictionary).get("orientation", ""))
	if orientation not in VALID_FINISHER_ORIENTATIONS:
		push_error("Finisher VFX orientation is unsupported: %s -> %s" % [profile_id, orientation])
		return false
	var particle_identity := profile.get("particle_identity", {}) as Dictionary
	var particle_count := int(particle_identity.get("count", 0))
	if particle_count <= 0 or particle_count > 256:
		push_error("Finisher VFX particle count must stay readable: %s" % profile_id)
		return false
	var palette := (profile.get("light_identity", {}) as Dictionary).get("palette", []) as Array
	if palette.size() < 3:
		push_error("Finisher VFX needs a layered three-color light palette: %s" % profile_id)
		return false
	var layer_stack := profile.get("layer_stack", []) as Array
	if layer_stack.size() < 10:
		push_error("Finisher VFX needs ten storyboard-driven visual layers: %s" % profile_id)
		return false
	return true


func _validate_beat_pattern(profile_id: String, value: Variant) -> bool:
	if not value is Array:
		push_error("Named skill VFX beat_pattern must be an array: %s" % profile_id)
		return false
	var beats := value as Array
	if beats.size() < 3 or beats.size() > 5:
		push_error("Named skill VFX beat_pattern needs three to five beats: %s" % profile_id)
		return false
	var previous := -1.0
	for beat in beats:
		if not beat is int and not beat is float:
			push_error("Named skill VFX beat_pattern must be numeric: %s" % profile_id)
			return false
		var current := float(beat)
		if current < 0.0 or current > 1.0 or current <= previous:
			push_error("Named skill VFX beat_pattern must increase within 0..1: %s" % profile_id)
			return false
		previous = current
	return true


func _validate_stack_progression(profile_id: String, profile: Dictionary) -> bool:
	var milestone_value: Variant = profile.get("stack_milestones", null)
	var trait_value: Variant = profile.get("stack_traits", null)
	if not milestone_value is Array or not trait_value is Array:
		push_error("Named skill VFX stack progression must use arrays: %s" % profile_id)
		return false
	var milestones := milestone_value as Array
	var traits := trait_value as Array
	if milestones.size() < 3 or milestones.size() != traits.size():
		push_error("Named skill VFX stack milestones and traits must align: %s" % profile_id)
		return false
	var previous := -1
	for milestone in milestones:
		if not milestone is int and not (
			milestone is float and is_equal_approx(float(milestone), roundf(float(milestone)))
		):
			push_error("Named skill VFX stack milestones must be integers: %s" % profile_id)
			return false
		var current := int(milestone)
		if current < 0 or current <= previous:
			push_error("Named skill VFX stack milestones must strictly increase: %s" % profile_id)
			return false
		previous = current
	if int(milestones[0]) != 0:
		push_error("Named skill VFX stack milestones must start at zero: %s" % profile_id)
		return false
	return _validate_string_sequence(profile_id, "stack_traits", traits, traits.size())


func _validate_string_sequence(
	profile_id: String,
	field: String,
	value: Variant,
	expected_size: int
) -> bool:
	if not value is Array or (value as Array).size() != expected_size:
		push_error(
			"Named skill VFX %s must contain %d entries: %s"
			% [field, expected_size, profile_id]
		)
		return false
	var seen: Dictionary = {}
	for entry in value as Array:
		if not entry is String:
			push_error("Named skill VFX %s entries must be strings: %s" % [field, profile_id])
			return false
		var text := String(entry).strip_edges()
		if text.is_empty() or seen.has(text):
			push_error("Named skill VFX %s entries must be non-empty and unique: %s" % [field, profile_id])
			return false
		seen[text] = true
	return true
