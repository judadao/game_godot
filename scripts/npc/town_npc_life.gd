class_name TownNPCLife
extends AnimatableBody2D

signal life_state_changed(state: StringName)

const INTERACTION_CATALOG_SCRIPT := preload("res://scripts/npc/town_npc_interaction_catalog.gd")
const STATE_IDLE: StringName = &"idle"
const STATE_EMOTE: StringName = &"emote"
const STATE_REST: StringName = &"rest"
const STATE_WANDER: StringName = &"wander"
const STATE_SOCIAL_WALK: StringName = &"social_walk"
const STATE_SOCIAL_GREET: StringName = &"social_greet"
const STATE_SOCIAL_CHAT: StringName = &"social_chat"
const STATE_SOCIAL_REACT: StringName = &"social_react"
const STATE_SOCIAL_FAREWELL: StringName = &"social_farewell"
const STATE_ROLE_ACTIVITY: StringName = &"role_activity"
const STATE_RETURN_HOME: StringName = &"return_home"
const STATE_EXTERNAL_CHAT: StringName = &"external_chat"
const SOCIAL_SEQUENCE_STATES: Array[StringName] = [
	STATE_SOCIAL_GREET,
	STATE_SOCIAL_CHAT,
	STATE_SOCIAL_REACT,
	STATE_SOCIAL_FAREWELL,
]
const EMOTE_STATES: Array[StringName] = [
	&"laugh", &"happy", &"surprised", &"sad", &"angry",
]
const ROLE_ACTIVITY_NAMES := {
	"traveler": &"watch_square",
	"witch": &"check_charms",
	"guard": &"watch_street",
	"grocer": &"arrange_goods",
	"scientist": &"inspect_notes",
	"innkeeper": &"welcome_guests",
}
const ROLE_ACTIVITY_FALLBACK_STATES := {
	"traveler": &"idle",
	"witch": &"happy",
	"guard": &"angry",
	"grocer": &"happy",
	"scientist": &"surprised",
	"innkeeper": &"chat",
}
const ROLE_ARCHETYPES := {
	"traveler": &"social",
	"witch": &"merchant",
	"guard": &"guard",
	"grocer": &"merchant",
	"scientist": &"scholar",
	"innkeeper": &"worker",
}
const WORK_ROLES: Array[String] = ["witch", "guard", "grocer", "scientist", "innkeeper"]

@export var life_enabled := true
@export_range(24.0, 140.0, 1.0) var roam_radius := 72.0
@export_range(20.0, 120.0, 1.0) var walk_speed := 48.0
@export_range(120.0, 420.0, 1.0) var social_radius := 340.0
@export_range(36.0, 72.0, 1.0) var social_spacing := 50.0
@export_range(55.0, 100.0, 1.0) var personal_space := 80.0
@export_range(1.0, 12.0, 0.1) var minimum_idle_seconds := 2.4
@export_range(1.0, 12.0, 0.1) var maximum_idle_seconds := 5.8
@export_range(1.0, 8.0, 0.1) var social_chat_seconds := 3.2
@export_range(0.0, 1.0, 0.01) var social_chance := 0.34
@export_range(0.0, 0.3, 0.01) var role_activity_chance := 0.18

@onready var npc_visual: TownNPCVisual = $Visual

var _rng := RandomNumberGenerator.new()
var _interaction_catalog: RefCounted
var _state: StringName = STATE_IDLE
var _home_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _state_timer := 0.0
var _partner: TownNPCLife
var _social_ready := false
var _social_leader := false
var _social_reaction: StringName = &"laugh"
var _last_social_sequence: Array[StringName] = []
var _active_interaction_id: StringName
var _last_completed_interaction_id: StringName
var _interaction_sequence: Array[Dictionary] = []
var _interaction_cooldown_remaining := 0.0
var _active_interaction_cooldown_seconds := 8.0
var _relationship_counts: Dictionary = {}
var _role_activity_name: StringName = &"observe_town"
var _external_lock := false
var _external_previous_ambient := false
var _completed_interactions := 0


func _ready() -> void:
	_home_position = position
	_target_position = position
	_rng.seed = _stable_seed()
	_interaction_catalog = INTERACTION_CATALOG_SCRIPT.new()
	if not _interaction_catalog.call("load_catalog"):
		_interaction_catalog = null
	if is_instance_valid(npc_visual):
		npc_visual.ambient_enabled = false
	_set_state(STATE_IDLE)
	_state_timer = _next_idle_duration()


func _process(delta: float) -> void:
	advance_life(delta)


func advance_life(delta: float) -> void:
	var step := maxf(delta, 0.0)
	_interaction_cooldown_remaining = maxf(0.0, _interaction_cooldown_remaining - step)
	if not life_enabled or _external_lock:
		return
	match _state:
		STATE_IDLE, STATE_EMOTE, STATE_REST, STATE_ROLE_ACTIVITY:
			_state_timer -= step
			if _state_timer <= 0.0:
				_choose_next_activity()
		STATE_WANDER, STATE_RETURN_HOME, STATE_SOCIAL_WALK:
			_advance_motion(step)
		STATE_SOCIAL_GREET, STATE_SOCIAL_CHAT, STATE_SOCIAL_REACT, STATE_SOCIAL_FAREWELL:
			if _social_leader:
				_advance_social_sequence(step)


func get_life_state() -> StringName:
	return _state


func get_home_position() -> Vector2:
	return _home_position


func get_wander_bounds() -> Vector2:
	var minimum_x := _home_position.x - roam_radius
	var maximum_x := _home_position.x + roam_radius
	for candidate in get_parent().get_children():
		var other := candidate as TownNPCLife
		if other == null or other == self:
			continue
		var other_home_x := other.get_home_position().x
		if other_home_x < _home_position.x:
			minimum_x = maxf(
				minimum_x,
				(_home_position.x + other_home_x) * 0.5 + personal_space * 0.5
			)
		elif other_home_x > _home_position.x:
			maximum_x = minf(
				maximum_x,
				(_home_position.x + other_home_x) * 0.5 - personal_space * 0.5
			)
	return Vector2(minimum_x, maximum_x)


func get_completed_interactions() -> int:
	return _completed_interactions


func get_social_partner() -> TownNPCLife:
	return _partner


func get_last_social_sequence() -> Array[StringName]:
	return _last_social_sequence.duplicate()


func get_last_social_reaction() -> StringName:
	return _social_reaction


func get_active_interaction_id() -> StringName:
	return _active_interaction_id


func get_last_completed_interaction_id() -> StringName:
	return _last_completed_interaction_id


func get_relationship_count(other: TownNPCLife) -> int:
	if not is_instance_valid(other):
		return 0
	return int(_relationship_counts.get(other._character_id(), 0))


func get_role_activity_name() -> StringName:
	return _role_activity_name


func is_available_for_social() -> bool:
	return (
		life_enabled
		and not _external_lock
		and _interaction_cooldown_remaining <= 0.0
		and _state == STATE_IDLE
		and not is_instance_valid(_partner)
	)


func request_rest(duration := 2.0) -> void:
	if _external_lock:
		return
	_cancel_social_pair()
	_set_state(STATE_REST)
	_state_timer = maxf(duration, 0.1)


func request_role_activity(duration := 2.0) -> void:
	if _external_lock:
		return
	_cancel_social_pair()
	_role_activity_name = _role_activity_for_character()
	_set_state(STATE_ROLE_ACTIVITY)
	_state_timer = maxf(duration, 0.1)


func cancel_social_interaction() -> void:
	if not is_instance_valid(_partner):
		return
	_cancel_social_pair()


func set_external_interaction(active: bool, partner_position := Vector2.ZERO) -> void:
	if active:
		if _external_lock:
			_face_toward(partner_position.x)
			return
		_cancel_social_pair()
		_external_lock = true
		_external_previous_ambient = npc_visual.ambient_enabled
		npc_visual.ambient_enabled = false
		_set_state(STATE_EXTERNAL_CHAT)
		_face_toward(partner_position.x)
		return
	if not _external_lock:
		return
	_external_lock = false
	npc_visual.ambient_enabled = _external_previous_ambient
	_partner = null
	_set_state(STATE_IDLE)
	_state_timer = _next_idle_duration()


func _choose_next_activity() -> void:
	var roll := _rng.randf()
	if roll < social_chance and _try_begin_social_pair():
		return
	var activity_roll := _rng.randf()
	if activity_roll < 0.50:
		var bounds := get_wander_bounds()
		_target_position = Vector2(
			_rng.randf_range(bounds.x, bounds.y),
			_home_position.y
		)
		_set_state(STATE_WANDER)
		return
	if activity_roll < 0.68:
		_set_state(STATE_REST)
		_state_timer = _rng.randf_range(1.8, 3.4)
		return
	if activity_roll < 0.68 + role_activity_chance:
		request_role_activity(_rng.randf_range(1.8, 3.2))
		return
	_set_state(STATE_EMOTE)
	_state_timer = _rng.randf_range(1.4, 2.2)


func _try_begin_social_pair() -> bool:
	var best_partner: TownNPCLife
	var best_distance := INF
	for candidate in get_parent().get_children():
		var other := candidate as TownNPCLife
		if other == null or other == self or not other.is_available_for_social():
			continue
		var distance := absf(other.position.x - position.x)
		if distance <= social_radius and distance < best_distance:
			best_distance = distance
			best_partner = other
	if not is_instance_valid(best_partner):
		return false
	var pair_spacing := _prepare_social_interaction(best_partner)
	var midpoint := (position.x + best_partner.position.x) * 0.5
	var self_is_left := position.x <= best_partner.position.x
	_begin_social_walk(
		best_partner,
		midpoint + (-pair_spacing if self_is_left else pair_spacing),
		get_instance_id() < best_partner.get_instance_id()
	)
	best_partner._begin_social_walk(
		self,
		midpoint + (pair_spacing if self_is_left else -pair_spacing),
		get_instance_id() > best_partner.get_instance_id()
	)
	return true


func _begin_social_walk(next_partner: TownNPCLife, target_x: float, leader: bool) -> void:
	_partner = next_partner
	_social_leader = leader
	_social_ready = false
	_last_social_sequence.clear()
	_target_position = Vector2(target_x, _home_position.y)
	_set_state(STATE_SOCIAL_WALK)


func _advance_motion(delta: float) -> void:
	var direction := signf(_target_position.x - position.x)
	if not is_zero_approx(direction):
		_face_toward(_target_position.x)
	position = position.move_toward(_target_position, walk_speed * delta)
	z_index = 1
	if position.distance_to(_target_position) > 0.5:
		return
	position = _target_position
	z_index = 0
	match _state:
		STATE_SOCIAL_WALK:
			_social_ready = true
			if is_instance_valid(_partner) and _partner._social_ready:
				if _social_leader:
					_begin_social_sequence_pair()
				elif _partner._social_leader:
					_partner._begin_social_sequence_pair()
		STATE_RETURN_HOME:
			_set_state(STATE_IDLE)
			_state_timer = _next_idle_duration()
		_:
			_set_state(STATE_IDLE)
			_state_timer = _rng.randf_range(1.2, 3.0)


func _begin_social_sequence_pair() -> void:
	if not _has_valid_social_pair():
		_cancel_social_pair()
		return
	if _social_reaction.is_empty():
		_social_reaction = _choose_social_reaction(_partner)
	if _partner._social_reaction.is_empty():
		_partner._social_reaction = _social_reaction
	_face_toward(_partner.position.x)
	_partner._face_toward(position.x)
	_set_social_phase_pair(STATE_SOCIAL_GREET, 0.7)


func _advance_social_sequence(delta: float) -> void:
	if not _has_valid_social_pair():
		_cancel_social_pair()
		return
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	match _state:
		STATE_SOCIAL_GREET:
			_set_social_phase_pair(STATE_SOCIAL_CHAT, social_chat_seconds)
		STATE_SOCIAL_CHAT:
			_set_social_phase_pair(STATE_SOCIAL_REACT, 0.9)
		STATE_SOCIAL_REACT:
			_set_social_phase_pair(STATE_SOCIAL_FAREWELL, 0.7)
		STATE_SOCIAL_FAREWELL:
			_finish_social_pair()


func _set_social_phase_pair(next_state: StringName, duration: float) -> void:
	if not _has_valid_social_pair() or not SOCIAL_SEQUENCE_STATES.has(next_state):
		_cancel_social_pair()
		return
	_set_state(next_state)
	_partner._set_state(next_state)
	_state_timer = maxf(duration, 0.1)
	_partner._state_timer = _state_timer
	_last_social_sequence.append(next_state)
	_partner._last_social_sequence.append(next_state)
	if next_state == STATE_SOCIAL_REACT:
		_play_visual(_social_reaction, &"happy")
		_partner._play_visual(_partner._social_reaction, &"happy")
	elif next_state == STATE_SOCIAL_CHAT:
		_play_visual(_catalog_visual_for_phase(&"conversation"), &"chat")
		_partner._play_visual(_partner._catalog_visual_for_phase(&"conversation"), &"chat")
	_face_toward(_partner.position.x)
	_partner._face_toward(position.x)


func _has_valid_social_pair() -> bool:
	return (
		is_instance_valid(_partner)
		and _partner._partner == self
		and not _external_lock
		and not _partner._external_lock
	)


func _finish_social_pair() -> void:
	var finished_partner := _partner
	var completed_interaction_id := _active_interaction_id
	var completed_cooldown := _active_interaction_cooldown_seconds
	_completed_interactions += 1
	_last_completed_interaction_id = completed_interaction_id
	_increment_relationship(finished_partner)
	_interaction_cooldown_remaining = completed_cooldown
	_active_interaction_id = &""
	_active_interaction_cooldown_seconds = 8.0
	_partner = null
	_social_ready = false
	_social_leader = false
	_target_position = _home_position
	_set_state(STATE_RETURN_HOME)
	if is_instance_valid(finished_partner):
		finished_partner._completed_interactions += 1
		finished_partner._last_completed_interaction_id = completed_interaction_id
		finished_partner._increment_relationship(self)
		finished_partner._interaction_cooldown_remaining = completed_cooldown
		finished_partner._active_interaction_id = &""
		finished_partner._active_interaction_cooldown_seconds = 8.0
		finished_partner._partner = null
		finished_partner._social_ready = false
		finished_partner._social_leader = false
		finished_partner._target_position = finished_partner._home_position
		finished_partner._set_state(STATE_RETURN_HOME)


func _cancel_social_pair() -> void:
	var cancelled_partner := _partner
	_active_interaction_id = &""
	_active_interaction_cooldown_seconds = 8.0
	_interaction_sequence.clear()
	_partner = null
	_social_ready = false
	_social_leader = false
	_target_position = _home_position
	if SOCIAL_SEQUENCE_STATES.has(_state) or _state == STATE_SOCIAL_WALK:
		_set_state(STATE_RETURN_HOME)
	if is_instance_valid(cancelled_partner) and cancelled_partner._partner == self:
		cancelled_partner._active_interaction_id = &""
		cancelled_partner._active_interaction_cooldown_seconds = 8.0
		cancelled_partner._interaction_sequence.clear()
		cancelled_partner._partner = null
		cancelled_partner._social_ready = false
		cancelled_partner._social_leader = false
		cancelled_partner._target_position = cancelled_partner._home_position
		cancelled_partner._set_state(STATE_RETURN_HOME)


func _set_state(next_state: StringName) -> void:
	_state = next_state
	match _state:
		STATE_WANDER, STATE_SOCIAL_WALK, STATE_RETURN_HOME:
			_play_visual(&"walk", &"idle")
		STATE_SOCIAL_GREET, STATE_SOCIAL_FAREWELL:
			_play_visual(&"greet", &"chat")
		STATE_SOCIAL_CHAT, STATE_EXTERNAL_CHAT:
			_play_visual(&"chat", &"idle")
		STATE_SOCIAL_REACT:
			_play_visual(_social_reaction, &"happy")
		STATE_REST:
			_play_visual(&"sit", &"idle")
		STATE_ROLE_ACTIVITY:
			_play_visual(&"work", _role_activity_fallback_state())
		STATE_EMOTE:
			_play_visual(EMOTE_STATES[_rng.randi_range(0, EMOTE_STATES.size() - 1)], &"idle_look")
		_:
			_play_visual(&"idle_look", &"idle")
	life_state_changed.emit(_state)


func _play_visual(preferred_state: StringName, fallback_state: StringName) -> void:
	if not is_instance_valid(npc_visual):
		return
	var supported := npc_visual.get_supported_states()
	if supported.has(preferred_state):
		npc_visual.play_state(preferred_state)
	elif supported.has(fallback_state):
		npc_visual.play_state(fallback_state)
	else:
		npc_visual.play_state(&"idle")


func _choose_social_reaction(other: TownNPCLife) -> StringName:
	var pair_ids := [_character_id(), other._character_id()]
	pair_ids.sort()
	if pair_ids == ["scientist", "witch"] or pair_ids == ["grocer", "scientist"]:
		return &"surprised"
	if pair_ids.has("guard") or pair_ids.has("innkeeper"):
		return &"happy"
	return &"laugh"


func _prepare_social_interaction(other: TownNPCLife) -> float:
	_social_reaction = &""
	other._social_reaction = &""
	_interaction_sequence.clear()
	other._interaction_sequence.clear()
	var preferred_spacing := social_spacing
	if _interaction_catalog == null:
		_social_reaction = _choose_social_reaction(other)
		other._social_reaction = _social_reaction
		return preferred_spacing
	var selected: Dictionary = _interaction_catalog.call(
		"select_candidate",
		StringName(_character_id()),
		_character_archetype(),
		StringName(other._character_id()),
		other._character_archetype(),
		_rng.randf(),
		_interaction_context_tags(other)
	)
	if selected.is_empty():
		selected = _interaction_catalog.call(
			"select_candidate",
			StringName(_character_id()),
			_character_archetype(),
			StringName(other._character_id()),
			other._character_archetype(),
			_rng.randf()
		)
	if selected.is_empty():
		_social_reaction = _choose_social_reaction(other)
		other._social_reaction = _social_reaction
		return preferred_spacing
	_active_interaction_id = StringName(selected.get("id", "chat"))
	other._active_interaction_id = _active_interaction_id
	_active_interaction_cooldown_seconds = maxf(
		float(selected.get("cooldown_seconds", 8.0)),
		8.0
	)
	other._active_interaction_cooldown_seconds = _active_interaction_cooldown_seconds
	_interaction_sequence = _copy_catalog_sequence(selected.get("actor_a_sequence", []))
	other._interaction_sequence = _copy_catalog_sequence(selected.get("actor_b_sequence", []))
	_social_reaction = _catalog_visual_for_phase(&"reaction")
	other._social_reaction = other._catalog_visual_for_phase(&"reaction")
	if _social_reaction.is_empty():
		_social_reaction = _choose_social_reaction(other)
	if other._social_reaction.is_empty():
		other._social_reaction = _social_reaction
	var distance_variant: Variant = selected.get("social_distance", {})
	if distance_variant is Dictionary:
		preferred_spacing = clampf(
			float((distance_variant as Dictionary).get("preferred", social_spacing * 2.0)) * 0.5,
			36.0,
			72.0
		)
	return preferred_spacing


func _interaction_context_tags(other: TownNPCLife) -> PackedStringArray:
	var relationship_count := get_relationship_count(other)
	if relationship_count <= 0:
		return PackedStringArray(["welcoming"])
	if _town_time_progress() >= 0.65:
		return PackedStringArray(["scenic"])
	if WORK_ROLES.has(_character_id()) and WORK_ROLES.has(other._character_id()):
		return PackedStringArray(["work"])
	if relationship_count >= 2:
		return PackedStringArray(["conversation"])
	return PackedStringArray(["relaxed"])


func _catalog_visual_for_phase(phase: StringName) -> StringName:
	var allowed: Array[StringName]
	match phase:
		&"conversation":
			allowed = [&"chat", &"work", &"idle_look", &"idle_stretch"]
		&"reaction":
			allowed = [&"laugh", &"happy", &"surprised", &"sad", &"angry"]
		_:
			return &""
	for step in _interaction_sequence:
		var state := StringName(step.get("state", ""))
		if allowed.has(state):
			return state
	return &""


func _copy_catalog_sequence(value: Variant) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	if not value is Array:
		return copied
	for step_variant in value as Array:
		if step_variant is Dictionary:
			copied.append((step_variant as Dictionary).duplicate(true))
	return copied


func _increment_relationship(other: TownNPCLife) -> void:
	if not is_instance_valid(other):
		return
	var relationship_key := other._character_id()
	_relationship_counts[relationship_key] = int(_relationship_counts.get(relationship_key, 0)) + 1


func _town_time_progress() -> float:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("get_time_of_day_contract"):
			var contract: Dictionary = ancestor.call("get_time_of_day_contract")
			return clampf(float(contract.get("progress", 0.0)), 0.0, 1.0)
		ancestor = ancestor.get_parent()
	return 0.0


func _role_activity_for_character() -> StringName:
	return ROLE_ACTIVITY_NAMES.get(_character_id(), &"observe_town")


func _role_activity_fallback_state() -> StringName:
	return ROLE_ACTIVITY_FALLBACK_STATES.get(_character_id(), &"idle")


func _character_id() -> String:
	return String(get_meta("character_id", name))


func _character_archetype() -> StringName:
	return ROLE_ARCHETYPES.get(_character_id(), &"resident")


func _face_toward(target_x: float) -> void:
	if is_instance_valid(npc_visual):
		npc_visual.set_facing_direction(target_x - position.x)


func _next_idle_duration() -> float:
	return _rng.randf_range(minimum_idle_seconds, maximum_idle_seconds)


func _stable_seed() -> int:
	return absi(hash(_character_id()) + int(round(position.x * 17.0))) + 1
