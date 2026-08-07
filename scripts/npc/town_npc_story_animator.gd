class_name TownNPCStoryAnimator
extends Node2D

const CATALOG_PATH := "res://data/town_npc_story_animations.json"
const GRID_COLUMNS := 4
const GRID_ROWS := 6

@onready var sprite: Sprite2D = %StorySprite

var _profiles: Dictionary = {}
var _profile: Dictionary = {}
var _active_kind := ""
var _active_state := &""
var _active_row := 0
var _frame := 0
var _elapsed := 0.0
var _fps := 8.0


func _ready() -> void:
	_load_catalog()
	set_process(false)


func set_character(character_id: StringName) -> bool:
	if _profiles.is_empty():
		_load_catalog()
	if not _profiles.has(character_id):
		return false
	_profile = _profiles[character_id] as Dictionary
	_active_kind = ""
	_active_state = &""
	return true


func get_supported_expressions() -> Array:
	return _get_states("expressions")


func get_supported_actions() -> Array:
	return _get_states("actions")


func play_expression(state_id: StringName) -> bool:
	return _play("expressions", state_id)


func play_action(state_id: StringName) -> bool:
	return _play("actions", state_id)


func stop_story_animation() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	var frame_duration := 1.0 / maxf(_fps, 1.0)
	while _elapsed >= frame_duration:
		_elapsed -= frame_duration
		_frame = (_frame + 1) % GRID_COLUMNS
		_apply_region()


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("NPC story animation catalog is missing: %s" % CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not parsed is Dictionary:
		push_error("NPC story animation catalog is invalid JSON.")
		return
	var catalog := parsed as Dictionary
	_fps = float((catalog.get("grid", {}) as Dictionary).get("fps", 8.0))
	for profile_variant in catalog.get("profiles", []) as Array:
		var profile := profile_variant as Dictionary
		_profiles[StringName(profile.get("id", ""))] = profile


func _get_states(kind: String) -> Array:
	if _profile.is_empty():
		return []
	return ((_profile.get(kind, {}) as Dictionary).get("states", []) as Array).duplicate()


func _play(kind: String, state_id: StringName) -> bool:
	if _profile.is_empty():
		return false
	var spec := _profile.get(kind, {}) as Dictionary
	var states := spec.get("states", []) as Array
	var row := states.find(String(state_id))
	if row < 0:
		return false
	var texture := load(String(spec.get("atlas_path", ""))) as Texture2D
	if texture == null:
		return false
	sprite.texture = texture
	sprite.region_enabled = true
	_active_kind = kind
	_active_state = state_id
	_active_row = row
	_frame = 0
	_elapsed = 0.0
	_apply_region()
	set_process(true)
	return true


func _apply_region() -> void:
	if sprite.texture == null:
		return
	var atlas_size := sprite.texture.get_size()
	var cell_size := Vector2(atlas_size.x / GRID_COLUMNS, atlas_size.y / GRID_ROWS)
	sprite.region_rect = Rect2(Vector2(_frame * cell_size.x, _active_row * cell_size.y), cell_size)
