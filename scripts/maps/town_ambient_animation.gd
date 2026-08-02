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
@export_range(12.0, 90.0, 0.5) var idle_wait_min := 45.0
@export_range(18.0, 120.0, 0.5) var idle_wait_max := 72.0
@export_range(3.0, 15.0, 0.5) var away_wait_min := 5.0
@export_range(5.0, 20.0, 0.5) var away_wait_max := 8.0
@export_range(0.25, 1.0, 0.01) var leaf_visual_scale := 0.48
@export_range(0.04, 0.12, 0.005) var bird_visual_scale := 0.065

@onready var canopy_layers: Node2D = $CanopyLayers
@onready var forest_sway_layers: Node2D = $ForestSwayLayers
@onready var house_sway_layers: Node2D = $HouseSwayLayers
@onready var settled_leaf_piles: Node2D = $SettledLeafPiles
@onready var bird_perches: Node2D = $BirdPerches
@onready var ancient_tree: Sprite2D = $CanopyLayers/AncientTreeWind

var _wind_state := WIND_CALM
var _wind_timer := 0.0
var _wind_wait := 6.0
var _wind_duration := 4.0
var _wind_direction := 1.0
var _ambient_time := 0.0
var _sunset_lighting_strength := 0.0
var _player_search_timer := 0.0
var _player: Node2D
var _canopy_clusters: Array[Dictionary] = []
var _forest_sway_clusters: Array[Dictionary] = []
var _forest_sway_sprite_layer_count := 0
var _leaf_streams: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _tree_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wind_wait = _rng.randf_range(calm_wait_min, calm_wait_max)
	_tree_material = ancient_tree.material as ShaderMaterial
	for child in $CanopyLayers/CanopyClusters.get_children():
		if child is Node2D:
			_register_canopy_cluster(child as Node2D)
	for child in forest_sway_layers.get_children():
		if child is Node2D:
			_register_forest_sway_cluster(child as Node2D)
	for child in house_sway_layers.get_children():
		if child is Node2D:
			_register_forest_sway_cluster(child as Node2D)
	_apply_sunset_lighting_to_material(_tree_material, 0.0)
	for child in canopy_layers.get_children():
		if child is Sprite2D and String(child.name).begins_with("LeafDrift"):
			_register_leaf_stream(child as Sprite2D)
	for child in bird_perches.get_children():
		if child is Sprite2D:
			_register_bird(child as Sprite2D)
	_resolve_player()


func _process(delta: float) -> void:
	_ambient_time += delta
	_player_search_timer -= delta
	if _player_search_timer <= 0.0:
		_resolve_player()
	_update_wind(delta)
	for leaf_index in _leaf_streams.size():
		_update_leaf_stream(leaf_index, delta)
	_update_settled_leaf_piles()
	for bird_index in _birds.size():
		_update_bird(bird_index, delta)


func get_ambient_contract() -> Dictionary:
	var roof_perches := 0
	var ground_perches := 0
	var street_leaf_landings := 0
	var roof_leaf_landings := 0
	var building_leaf_landings := 0
	for bird in _birds:
		var sprite: Sprite2D = bird["sprite"] as Sprite2D
		var perch_kind := String(sprite.get_meta("perch_kind", ""))
		if perch_kind == "roof":
			roof_perches += 1
		elif perch_kind == "ground":
			ground_perches += 1
	for leaf in _leaf_streams:
		var leaf_sprite := leaf["sprite"] as Sprite2D
		match String(leaf_sprite.get_meta("landing_surface", "")):
			"street":
				street_leaf_landings += 1
			"roof":
				roof_leaf_landings += 1
			"building":
				building_leaf_landings += 1
	return {
		"frame_count": FRAME_COUNT,
		"ancient_tree_source": ancient_tree.texture.resource_path,
		"tree_base_static": true,
		"calm_canopy_motion": true,
		"sunset_leaf_shimmer": true,
		"canopy_clusters": _canopy_clusters.size(),
		"forest_sway_clusters": forest_sway_layers.get_child_count(),
		"house_sway_clusters": house_sway_layers.get_child_count(),
		"total_sway_clusters": _forest_sway_clusters.size(),
		"forest_sway_sprite_layers": _forest_sway_sprite_layer_count,
		"forest_patch_assets": 3,
		"forest_trunk_anchors": 0,
		"leaf_streams": _leaf_streams.size(),
		"street_leaf_landings": street_leaf_landings,
		"roof_leaf_landings": roof_leaf_landings,
		"building_leaf_landings": building_leaf_landings,
		"settled_leaf_piles": settled_leaf_piles.get_child_count(),
		"leaf_visual_scale": leaf_visual_scale,
		"bird_count": _birds.size(),
		"roof_perches": roof_perches,
		"ground_perches": ground_perches,
		"bird_visual_scale": bird_visual_scale,
		"calm_wait_min": calm_wait_min,
		"idle_wait_min": idle_wait_min,
		"idle_wait_max": idle_wait_max,
		"collision_owned": false,
	}


func set_sunset_lighting_strength(strength: float) -> void:
	_sunset_lighting_strength = clampf(strength, 0.0, 1.0)
	_apply_sunset_lighting_to_material(_tree_material, 0.0)
	for layer in _canopy_clusters:
		_apply_sunset_lighting_to_material(
			layer.get("foliage_material") as ShaderMaterial,
			float(layer["phase"])
		)
	for layer in _forest_sway_clusters:
		for sprite_layer_variant in layer["sprite_layers"] as Array:
			var sprite_layer := sprite_layer_variant as Dictionary
			_apply_sunset_lighting_to_material(
				sprite_layer.get("foliage_material") as ShaderMaterial,
				float(layer["phase"]) + float(sprite_layer["sway_gain"])
			)


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
	var phase := float(pivot.get_meta("phase", 0.0))
	var foliage_sprite := pivot.get_node_or_null("Sprite") as Sprite2D
	var foliage_material := _create_foliage_material(foliage_sprite, phase)
	_canopy_clusters.append({
		"pivot": pivot,
		"base_position": pivot.position,
		"base_rotation": pivot.rotation,
		"max_rotation": float(pivot.get_meta("max_rotation", 0.012)),
		"gust_delay": float(pivot.get_meta("gust_delay", 0.0)),
		"phase": phase,
		"calm_period": float(pivot.get_meta("calm_period", 4.8)),
		"rustle_period": float(pivot.get_meta("rustle_period", 6.5)),
		"calm_gain": float(pivot.get_meta("calm_gain", 1.0)),
		"foliage_material": foliage_material,
	})


func _register_forest_sway_cluster(pivot: Node2D) -> void:
	var sprite_layers: Array[Dictionary] = []
	for child in pivot.get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		var material_phase := (
			float(pivot.get_meta("phase", 0.0))
			+ float(sprite.get_meta("sway_gain", 0.65))
		)
		sprite_layers.append({
			"sprite": sprite,
			"base_rotation": sprite.rotation,
			"sway_gain": float(sprite.get_meta("sway_gain", 0.65)),
			"foliage_material": _create_foliage_material(
				sprite,
				material_phase
			),
		})
	_forest_sway_sprite_layer_count += sprite_layers.size()
	_forest_sway_clusters.append({
		"pivot": pivot,
		"base_position": pivot.position,
		"base_rotation": pivot.rotation,
		"base_scale": pivot.scale,
		"base_skew": pivot.skew,
		"max_rotation": float(pivot.get_meta("max_rotation", 0.04)),
		"phase": float(pivot.get_meta("phase", 0.0)),
		"calm_period": float(pivot.get_meta("calm_period", 4.8)),
		"rustle_period": float(pivot.get_meta("rustle_period", 6.5)),
		"sprite_layers": sprite_layers,
	})


func _register_leaf_stream(sprite: Sprite2D) -> void:
	sprite.scale *= leaf_visual_scale
	var base_color := sprite.modulate
	var initial_delay := float(sprite.get_meta("initial_delay", 0.0))
	_leaf_streams.append({
		"sprite": sprite,
		"start": sprite.position,
		"landing_y": float(sprite.get_meta("landing_y", 625.0)),
		"drift_x": float(sprite.get_meta("drift_x", 140.0)),
		"duration": float(sprite.get_meta("fall_duration", 8.0)),
		"hold": float(sprite.get_meta("ground_hold", 1.8)),
		"landing_rotation": float(sprite.get_meta("landing_rotation", 0.0)),
		"fade_duration": float(sprite.get_meta("fade_duration", 1.2)),
		"wait_min": float(sprite.get_meta("wait_min", 3.0)),
		"wait_max": float(sprite.get_meta("wait_max", 8.0)),
		"phase": _rng.randf_range(0.0, TAU),
		"base_color": base_color,
		"state": LEAF_WAIT,
		"timer": -initial_delay,
		"wait": _rng.randf_range(0.5, 3.0),
	})
	sprite.visible = false


func _update_settled_leaf_piles() -> void:
	for child in settled_leaf_piles.get_children():
		var pile := child as Node2D
		if pile == null:
			continue
		var phase := float(pile.get_meta("phase", 0.0))
		var cycle := fposmod(_ambient_time + phase, 40.0)
		var alpha := 0.0
		if cycle < 2.0:
			alpha = cycle / 2.0
		elif cycle < 32.0:
			alpha = 1.0
		elif cycle < 36.0:
			alpha = 1.0 - (cycle - 32.0) / 4.0
		pile.modulate.a = alpha


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
	var perch_kind := String(sprite.get_meta("perch_kind", "roof"))
	var idle_frame_count := 4 if perch_kind == "roof" else FRAME_COUNT
	var authored_scale := float(sprite.get_meta("visual_scale", bird_visual_scale))
	sprite.texture = BIRD_IDLE_TEXTURE
	sprite.scale = Vector2.ONE * authored_scale
	sprite.modulate = Color(0.52, 0.68, 0.95, 1.0)
	sprite.frame = _rng.randi_range(0, idle_frame_count - 1)
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
		"idle_frame_count": idle_frame_count,
		"direction": 1.0,
	})


func _resolve_player() -> void:
	_player_search_timer = 0.5
	var candidate := get_tree().get_first_node_in_group(PLAYER_GROUP) as Node2D
	_player = candidate


func _update_wind(delta: float) -> void:
	_wind_timer += delta
	if _wind_state == WIND_CALM:
		_apply_calm_pose()
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


func _apply_calm_pose() -> void:
	_stabilize_tree_base(_ambient_time)
	for layer in _canopy_clusters:
		var phase := float(layer["phase"])
		var calm_period := float(layer["calm_period"])
		var rustle_period := float(layer["rustle_period"])
		var calm_gain := float(layer["calm_gain"])
		var branch_sway := sin(
			_ambient_time * TAU / calm_period + phase
		) * 0.18
		var rustle_gate := pow(
			maxf(
				0.0,
				sin(
					_ambient_time * TAU / rustle_period
					+ phase * 1.37
				)
			),
			6.0
		)
		var sparse_rustle := (
			sin(_ambient_time * TAU / 0.7 + phase * 2.1)
			* rustle_gate
			* 0.32
		)
		_apply_canopy_transform(
			layer,
			(branch_sway + sparse_rustle) * calm_gain
		)
	for layer in _forest_sway_clusters:
		var phase := float(layer["phase"])
		var calm_period := float(layer["calm_period"])
		var rustle_period := float(layer["rustle_period"])
		var foliage_sway := sin(
			_ambient_time * TAU / calm_period + phase
		) * 0.52
		var rustle_gate := pow(
			maxf(
				0.0,
				sin(
					_ambient_time * TAU / rustle_period
					+ phase * 1.51
				)
			),
			7.0
		)
		var local_rustle := (
			sin(_ambient_time * TAU / 0.8 + phase * 2.3)
			* rustle_gate
			* 0.38
		)
		_apply_forest_patch_transform(
			layer,
			foliage_sway + local_rustle
		)


func _apply_wind_pose(progress: float) -> void:
	_stabilize_tree_base(progress * PI)
	for layer in _canopy_clusters:
		var gust_delay := float(layer["gust_delay"])
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
		_apply_canopy_transform(
			layer,
			envelope * ripple * _wind_direction
		)
	for layer in _forest_sway_clusters:
		var phase := float(layer["phase"])
		var envelope := sin(progress * PI)
		var local_strength := envelope * (
			0.78
			+ sin(progress * TAU * 1.1 + phase) * 0.22
		)
		_apply_forest_patch_transform(
			layer,
			local_strength * _wind_direction
		)


func _stabilize_tree_base(phase: float) -> void:
	if _tree_material != null:
		_tree_material.set_shader_parameter("wind_strength", 0.0)
		_tree_material.set_shader_parameter("wind_phase", phase)
		_tree_material.set_shader_parameter(
			"shimmer_time",
			_ambient_time
		)


func _apply_canopy_transform(
	layer: Dictionary,
	strength: float
) -> void:
	var pivot: Node2D = layer["pivot"] as Node2D
	var base_position := layer["base_position"] as Vector2
	var base_rotation := float(layer["base_rotation"])
	var max_rotation := float(layer["max_rotation"])
	pivot.rotation = base_rotation + strength * max_rotation
	pivot.position = base_position
	var foliage_material := layer.get("foliage_material") as ShaderMaterial
	if foliage_material != null:
		foliage_material.set_shader_parameter(
			"shimmer_time",
			_ambient_time + float(layer["phase"])
		)
		foliage_material.set_shader_parameter(
			"wind_phase",
			strength * 0.65 + float(layer["phase"])
		)


func _apply_forest_patch_transform(
	layer: Dictionary,
	strength: float
) -> void:
	var pivot: Node2D = layer["pivot"] as Node2D
	var base_position := layer["base_position"] as Vector2
	var base_rotation := float(layer["base_rotation"])
	var base_scale := layer["base_scale"] as Vector2
	var base_skew := float(layer["base_skew"])
	var max_rotation := float(layer["max_rotation"])
	var pivot_gain := 0.45
	pivot.rotation = base_rotation + strength * max_rotation * pivot_gain
	pivot.position = base_position
	pivot.scale = base_scale
	pivot.skew = base_skew
	for sprite_layer_variant in layer["sprite_layers"] as Array:
		var sprite_layer := sprite_layer_variant as Dictionary
		var sprite := sprite_layer["sprite"] as Sprite2D
		var sprite_base_rotation := float(sprite_layer["base_rotation"])
		var sway_gain := float(sprite_layer["sway_gain"])
		sprite.rotation = (
			sprite_base_rotation
			+ strength * max_rotation * (sway_gain - pivot_gain)
		)
		var foliage_material := (
			sprite_layer.get("foliage_material") as ShaderMaterial
		)
		if foliage_material != null:
			foliage_material.set_shader_parameter(
				"shimmer_time",
				_ambient_time + float(layer["phase"]) + sway_gain
			)
			foliage_material.set_shader_parameter(
				"wind_phase",
				strength * 0.48 + float(layer["phase"]) + sway_gain
			)


func _create_foliage_material(
	sprite: Sprite2D,
	phase: float
) -> ShaderMaterial:
	if sprite == null or _tree_material == null:
		return null
	var foliage_material := _tree_material.duplicate() as ShaderMaterial
	if foliage_material == null:
		return null
	foliage_material.resource_local_to_scene = true
	foliage_material.set_shader_parameter("wind_strength", 0.0)
	foliage_material.set_shader_parameter("shimmer_phase", phase)
	sprite.material = foliage_material
	_apply_sunset_lighting_to_material(foliage_material, phase)
	return foliage_material


func _apply_sunset_lighting_to_material(
	material: ShaderMaterial,
	phase: float
) -> void:
	if material == null:
		return
	material.set_shader_parameter(
		"sunset_light_strength",
		_sunset_lighting_strength
	)
	material.set_shader_parameter("shimmer_phase", phase)


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
			sprite.rotation = lerpf(
				sprite.rotation,
				float(leaf["landing_rotation"]),
				delta * 3.0
			)
			if timer >= float(leaf["hold"]):
				leaf["state"] = LEAF_FADE
				leaf["timer"] = 0.0
		LEAF_FADE:
			var fade_progress := clampf(timer / float(leaf["fade_duration"]), 0.0, 1.0)
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
				% int(bird["idle_frame_count"])
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
	sprite.frame = _rng.randi_range(0, int(bird["idle_frame_count"]) - 1)
	sprite.flip_h = _rng.randi_range(0, 1) == 0
	bird["state"] = BIRD_IDLE
	bird["timer"] = 0.0
	bird["wait"] = _rng.randf_range(idle_wait_min, idle_wait_max)
	bird["phase"] = float(sprite.frame)
