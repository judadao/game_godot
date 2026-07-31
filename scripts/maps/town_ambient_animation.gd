extends Node2D

const FRAME_COUNT := 12
const WIND_CALM := 0
const WIND_GUST := 1
const LEAF_WAIT := 0
const LEAF_FALL := 1
const LEAF_LANDED := 2
const LEAF_FADE := 3
const BIRD_IDLE := 0
const BIRD_TAKEOFF := 1
const BIRD_FLIGHT := 2
const BIRD_AWAY := 3
const BIRD_IDLE_FPS := 3.0
const BIRD_FLIGHT_FPS := 8.0
const TAKEOFF_SECONDS := 0.5
const FLIGHT_SECONDS := 1.8
const PLAYER_GROUP := &"Player"
const BIRD_IDLE_TEXTURE: Texture2D = preload(
	"res://assets/town/modular_v3/ambient/bird_idle_sheet.png"
)
const BIRD_FLIGHT_TEXTURE: Texture2D = preload(
	"res://assets/town/modular_v3/ambient/bird_flight_sheet.png"
)

@export_range(3.0, 20.0, 0.5) var calm_wait_min := 8.0
@export_range(4.0, 30.0, 0.5) var calm_wait_max := 18.0
@export_range(1.0, 8.0, 0.1) var gust_duration_min := 3.2
@export_range(1.0, 10.0, 0.1) var gust_duration_max := 4.8
@export_range(6.0, 30.0, 0.5) var idle_wait_min := 10.0
@export_range(8.0, 45.0, 0.5) var idle_wait_max := 22.0
@export_range(5.0, 30.0, 0.5) var away_wait_min := 9.0
@export_range(8.0, 45.0, 0.5) var away_wait_max := 18.0

@onready var canopy_layers: Node2D = $CanopyLayers
@onready var bird_perches: Node2D = $BirdPerches
@onready var ancient_tree: Sprite2D = $CanopyLayers/AncientTreeWind

var _wind_state := WIND_CALM
var _wind_timer := 0.0
var _wind_wait := 6.0
var _wind_duration := 4.0
var _wind_direction := 1.0
var _player_search_timer := 0.0
var _player: Node2D
var _canopy_clusters: Array[Dictionary] = []
var _leaf_streams: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _tree_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wind_wait = _rng.randf_range(calm_wait_min, calm_wait_max)
	for child in $CanopyLayers/CanopyClusters.get_children():
		if child is Node2D:
			_register_canopy_cluster(child as Node2D)
	_tree_material = ancient_tree.material as ShaderMaterial
	for child in canopy_layers.get_children():
		if child is Sprite2D and String(child.name).begins_with("LeafDrift"):
			_register_leaf_stream(child as Sprite2D)
	for child in bird_perches.get_children():
		if child is Sprite2D:
			_register_bird(child as Sprite2D)
	_resolve_player()


func _process(delta: float) -> void:
	_player_search_timer -= delta
	if _player_search_timer <= 0.0:
		_resolve_player()
	_update_wind(delta)
	for leaf_index in _leaf_streams.size():
		_update_leaf_stream(leaf_index, delta)
	for bird_index in _birds.size():
		_update_bird(bird_index, delta)


func get_ambient_contract() -> Dictionary:
	var roof_perches := 0
	var ground_perches := 0
	for bird in _birds:
		var sprite: Sprite2D = bird["sprite"] as Sprite2D
		var perch_kind := String(sprite.get_meta("perch_kind", ""))
		if perch_kind == "roof":
			roof_perches += 1
		elif perch_kind == "ground":
			ground_perches += 1
	return {
		"frame_count": FRAME_COUNT,
		"ancient_tree_source": ancient_tree.texture.resource_path,
		"canopy_clusters": _canopy_clusters.size(),
		"leaf_streams": _leaf_streams.size(),
		"bird_count": _birds.size(),
		"roof_perches": roof_perches,
		"ground_perches": ground_perches,
		"calm_wait_min": calm_wait_min,
		"idle_wait_min": idle_wait_min,
		"idle_wait_max": idle_wait_max,
		"collision_owned": false,
	}


func force_bird_takeoff(bird_name: StringName) -> void:
	for bird_index in _birds.size():
		var bird: Dictionary = _birds[bird_index]
		var sprite: Sprite2D = bird["sprite"] as Sprite2D
		if sprite.name != bird_name or int(bird["state"]) != BIRD_IDLE:
			continue
		var approach_position := sprite.global_position + Vector2(1.0, 0.0)
		_begin_bird_group_flight(bird_index, approach_position)
		return


func _register_canopy_cluster(pivot: Node2D) -> void:
	_canopy_clusters.append({
		"pivot": pivot,
		"base_position": pivot.position,
		"base_rotation": pivot.rotation,
		"max_rotation": float(pivot.get_meta("max_rotation", 0.012)),
		"gust_delay": float(pivot.get_meta("gust_delay", 0.0)),
		"sway_pixels": float(pivot.get_meta("sway_pixels", 1.5)),
		"phase": float(pivot.get_meta("phase", 0.0)),
	})


func _register_leaf_stream(sprite: Sprite2D) -> void:
	var base_color := sprite.modulate
	var initial_delay := float(sprite.get_meta("initial_delay", 0.0))
	_leaf_streams.append({
		"sprite": sprite,
		"start": sprite.position,
		"landing_y": float(sprite.get_meta("landing_y", 625.0)),
		"drift_x": float(sprite.get_meta("drift_x", 140.0)),
		"duration": float(sprite.get_meta("fall_duration", 8.0)),
		"hold": float(sprite.get_meta("ground_hold", 1.8)),
		"wait_min": float(sprite.get_meta("wait_min", 3.0)),
		"wait_max": float(sprite.get_meta("wait_max", 8.0)),
		"phase": _rng.randf_range(0.0, TAU),
		"base_color": base_color,
		"state": LEAF_WAIT,
		"timer": -initial_delay,
		"wait": _rng.randf_range(0.5, 3.0),
	})
	sprite.visible = false


func _register_bird(sprite: Sprite2D) -> void:
	var raw_offset: Variant = sprite.get_meta(
		"flight_offset",
		Vector2(150.0, -42.0)
	)
	var flight_offset := (
		raw_offset as Vector2
		if raw_offset is Vector2
		else Vector2(150.0, -42.0)
	)
	sprite.texture = BIRD_IDLE_TEXTURE
	sprite.frame = _rng.randi_range(0, FRAME_COUNT - 1)
	_birds.append({
		"sprite": sprite,
		"perch": sprite.position,
		"flight_offset": flight_offset,
		"flock_id": String(sprite.get_meta("flock_id", "")),
		"flock_order": int(sprite.get_meta("flock_order", 0)),
		"state": BIRD_IDLE,
		"timer": _rng.randf_range(0.0, 3.0),
		"wait": _rng.randf_range(idle_wait_min, idle_wait_max),
		"phase": float(sprite.frame),
		"direction": 1.0,
	})


func _resolve_player() -> void:
	_player_search_timer = 0.5
	var candidate := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	_player = candidate


func _update_wind(delta: float) -> void:
	_wind_timer += delta
	if _wind_state == WIND_CALM:
		_apply_wind_pose(0.0)
		if _wind_timer < _wind_wait:
			return
		_wind_state = WIND_GUST
		_wind_timer = 0.0
		_wind_duration = _rng.randf_range(
			gust_duration_min,
			gust_duration_max
		)
		_wind_direction = -1.0 if _rng.randf() < 0.18 else 1.0
		return

	var progress := clampf(_wind_timer / _wind_duration, 0.0, 1.0)
	_apply_wind_pose(progress)
	if progress < 1.0:
		return
	_wind_state = WIND_CALM
	_wind_timer = 0.0
	_wind_wait = _rng.randf_range(calm_wait_min, calm_wait_max)


func _apply_wind_pose(progress: float) -> void:
	var tree_strength := sin(progress * PI)
	if _tree_material != null:
		_tree_material.set_shader_parameter(
			"wind_strength",
			tree_strength * 7.0 * _wind_direction
		)
		_tree_material.set_shader_parameter(
			"wind_phase",
			progress * PI
		)
	for layer in _canopy_clusters:
		var pivot: Node2D = layer["pivot"] as Node2D
		var base_position := layer["base_position"] as Vector2
		var base_rotation := float(layer["base_rotation"])
		var max_rotation := float(layer["max_rotation"])
		var gust_delay := float(layer["gust_delay"])
		var sway_pixels := float(layer["sway_pixels"])
		var phase := float(layer["phase"])
		var local_progress := clampf(
			(progress - gust_delay) / (1.0 - gust_delay),
			0.0,
			1.0
		)
		var envelope := sin(local_progress * PI)
		var ripple := (
			0.72
			+ sin(local_progress * TAU * 1.35 + phase) * 0.28
		)
		var local_strength := envelope * ripple
		pivot.rotation = (
			base_rotation
			+ local_strength * max_rotation * _wind_direction
		)
		pivot.position = (
			base_position
			+ Vector2(
				local_strength * sway_pixels * _wind_direction,
				-sin(local_progress * TAU + phase) * envelope * 0.35
			)
		)


func _update_leaf_stream(leaf_index: int, delta: float) -> void:
	var leaf: Dictionary = _leaf_streams[leaf_index]
	var sprite: Sprite2D = leaf["sprite"] as Sprite2D
	var state := int(leaf["state"])
	var timer := float(leaf["timer"]) + delta
	leaf["timer"] = timer

	match state:
		LEAF_WAIT:
			sprite.visible = false
			if timer >= float(leaf["wait"]):
				sprite.visible = true
				sprite.position = leaf["start"] as Vector2
				sprite.modulate = leaf["base_color"] as Color
				leaf["state"] = LEAF_FALL
				leaf["timer"] = 0.0
		LEAF_FALL:
			var progress := clampf(
				timer / float(leaf["duration"]),
				0.0,
				1.0
			)
			var start := leaf["start"] as Vector2
			var drift_x := float(leaf["drift_x"])
			var landing_y := float(leaf["landing_y"])
			var phase := float(leaf["phase"])
			var side_sway := sin(progress * TAU * 1.5 + phase) * 10.0
			sprite.position = Vector2(
				start.x + drift_x * progress + side_sway,
				start.y + (landing_y - start.y) * pow(progress, 1.12)
			)
			sprite.rotation = sin(progress * TAU * 2.0 + phase) * 0.16
			var base_color := leaf["base_color"] as Color
			sprite.modulate = Color(
				base_color.r,
				base_color.g,
				base_color.b,
				base_color.a * minf(1.0, progress * 8.0)
			)
			if progress >= 1.0:
				leaf["state"] = LEAF_LANDED
				leaf["timer"] = 0.0
		LEAF_LANDED:
			sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 3.0)
			if timer >= float(leaf["hold"]):
				leaf["state"] = LEAF_FADE
				leaf["timer"] = 0.0
		LEAF_FADE:
			var fade_progress := clampf(timer / 1.2, 0.0, 1.0)
			var base_color := leaf["base_color"] as Color
			sprite.modulate = Color(
				base_color.r,
				base_color.g,
				base_color.b,
				base_color.a * (1.0 - fade_progress)
			)
			if fade_progress >= 1.0:
				leaf["state"] = LEAF_WAIT
				leaf["timer"] = 0.0
				leaf["wait"] = _rng.randf_range(
					float(leaf["wait_min"]),
					float(leaf["wait_max"])
				)
				leaf["phase"] = _rng.randf_range(0.0, TAU)

	_leaf_streams[leaf_index] = leaf


func _update_bird(bird_index: int, delta: float) -> void:
	var bird: Dictionary = _birds[bird_index]
	var sprite: Sprite2D = bird["sprite"] as Sprite2D
	var state := int(bird["state"])
	var timer := float(bird["timer"]) + delta
	bird["timer"] = timer

	match state:
		BIRD_IDLE:
			sprite.texture = BIRD_IDLE_TEXTURE
			sprite.frame = (
				int(floor(timer * BIRD_IDLE_FPS + float(bird["phase"])))
				% FRAME_COUNT
			)
			if _should_takeoff(sprite, timer, float(bird["wait"])):
				_birds[bird_index] = bird
				var approach := (
					_player.global_position
					if _player != null
					else sprite.global_position - Vector2(1.0, 0.0)
				)
				_begin_bird_group_flight(bird_index, approach)
				return
		BIRD_TAKEOFF:
			if timer < 0.0:
				sprite.frame = 0
				_birds[bird_index] = bird
				return
			var takeoff_progress := clampf(
				timer / TAKEOFF_SECONDS,
				0.0,
				1.0
			)
			sprite.frame = mini(3, int(floor(timer * BIRD_FLIGHT_FPS)))
			var perch := bird["perch"] as Vector2
			var direction := float(bird["direction"])
			sprite.position = perch + Vector2(
				direction * 22.0 * takeoff_progress,
				-22.0 * takeoff_progress * takeoff_progress
			)
			if timer >= TAKEOFF_SECONDS:
				bird["state"] = BIRD_FLIGHT
				bird["timer"] = 0.0
		BIRD_FLIGHT:
			var flight_progress := clampf(
				timer / FLIGHT_SECONDS,
				0.0,
				1.0
			)
			sprite.frame = 4 + int(floor(timer * BIRD_FLIGHT_FPS)) % 8
			var perch := bird["perch"] as Vector2
			var authored_offset := bird["flight_offset"] as Vector2
			var direction := float(bird["direction"])
			var travel := Vector2(
				absf(authored_offset.x) * direction * flight_progress,
				authored_offset.y * flight_progress
					- sin(flight_progress * PI) * 54.0
			)
			sprite.position = perch + travel
			if timer >= FLIGHT_SECONDS:
				sprite.visible = false
				bird["state"] = BIRD_AWAY
				bird["timer"] = 0.0
				bird["wait"] = _rng.randf_range(
					away_wait_min,
					away_wait_max
				)
		BIRD_AWAY:
			if timer >= float(bird["wait"]):
				_reset_bird(bird)

	_birds[bird_index] = bird


func _should_takeoff(
	sprite: Sprite2D,
	timer: float,
	wait_seconds: float
) -> bool:
	if timer >= wait_seconds:
		return true
	if timer < 1.5 or _player == null:
		return false
	var raw_distance: Variant = sprite.get_meta("trigger_distance", 105.0)
	var trigger_distance := float(raw_distance)
	return sprite.global_position.distance_to(_player.global_position) <= trigger_distance


func _begin_bird_group_flight(
	bird_index: int,
	approach_position: Vector2
) -> void:
	var source: Dictionary = _birds[bird_index]
	var flock_id := String(source["flock_id"])
	if flock_id.is_empty():
		_begin_bird_flight(bird_index, approach_position, 0.0)
		return
	for candidate_index in _birds.size():
		var candidate: Dictionary = _birds[candidate_index]
		if (
			String(candidate["flock_id"]) != flock_id
			or int(candidate["state"]) != BIRD_IDLE
		):
			continue
		var delay := float(candidate["flock_order"]) * 0.12
		_begin_bird_flight(candidate_index, approach_position, delay)


func _begin_bird_flight(
	bird_index: int,
	approach_position: Vector2,
	delay: float
) -> void:
	var bird: Dictionary = _birds[bird_index]
	var sprite: Sprite2D = bird["sprite"] as Sprite2D
	var direction := -1.0 if approach_position.x >= sprite.global_position.x else 1.0
	bird["state"] = BIRD_TAKEOFF
	bird["timer"] = -delay
	bird["direction"] = direction
	sprite.texture = BIRD_FLIGHT_TEXTURE
	sprite.frame = 0
	sprite.flip_h = direction < 0.0
	_birds[bird_index] = bird


func _reset_bird(bird: Dictionary) -> void:
	var sprite: Sprite2D = bird["sprite"] as Sprite2D
	sprite.visible = true
	sprite.texture = BIRD_IDLE_TEXTURE
	sprite.position = bird["perch"] as Vector2
	sprite.frame = _rng.randi_range(0, FRAME_COUNT - 1)
	sprite.flip_h = _rng.randi_range(0, 1) == 0
	bird["state"] = BIRD_IDLE
	bird["timer"] = 0.0
	bird["wait"] = _rng.randf_range(idle_wait_min, idle_wait_max)
	bird["phase"] = float(sprite.frame)
