extends Node2D

const CAMERA_X := 960.0
const CAMERA_MIN_Y := 420.0
const CAMERA_MAX_Y := 1280.0
const CAMERA_PLAYER_OFFSET_Y := 50.0
const BOSS_PRESENTATION_Z := 0
const PLAYER_FOREGROUND_Z := 30
const BOSS_HEAD_FRAME_OFFSET_Y := 380.0
const BOSS_TRACK_MIN_X := 760.0
const BOSS_TRACK_MAX_X := 1160.0

@onready var player: Node2D = get_node_or_null("Player") as Node2D
@onready var overview_camera: Camera2D = get_node_or_null("ArenaOverviewCamera") as Camera2D
@onready var boss_director: Node = get_node_or_null("RegionalBossDirector")
var _active_background_boss: Node2D


func _ready() -> void:
	var player_camera := get_node_or_null("Player/Camera2D") as Camera2D
	if player_camera != null:
		player_camera.enabled = false
	if overview_camera != null:
		overview_camera.enabled = true
	if player != null:
		player.z_index = PLAYER_FOREGROUND_Z
		player.set("jump_velocity", -680.0)
	if boss_director != null and boss_director.has_signal("boss_spawned"):
		boss_director.connect("boss_spawned", _on_boss_spawned)


func _process(delta: float) -> void:
	if overview_camera == null or player == null:
		return
	# Keep the player above the tall bottom HUD while retaining generous space above
	# for the colossus head, arms, and the next reachable platform.
	var target_y := clampf(player.global_position.y + CAMERA_PLAYER_OFFSET_Y, CAMERA_MIN_Y, CAMERA_MAX_Y)
	overview_camera.position = overview_camera.position.lerp(Vector2(CAMERA_X, target_y), minf(delta * 5.0, 1.0))
	if _active_background_boss != null and is_instance_valid(_active_background_boss):
		var boss_target := Vector2(
			clampf(player.global_position.x, BOSS_TRACK_MIN_X, BOSS_TRACK_MAX_X),
			overview_camera.position.y + BOSS_HEAD_FRAME_OFFSET_Y
		)
		_active_background_boss.global_position = _active_background_boss.global_position.lerp(
			boss_target,
			minf(delta * 0.8, 1.0)
		)


func _on_boss_spawned(boss: Node, _completion_boss: bool, _remaining: float) -> void:
	if boss is not Node2D:
		return
	var boss_visual := boss as Node2D
	_active_background_boss = boss_visual
	boss_visual.z_index = BOSS_PRESENTATION_Z
	boss_visual.set_meta("presentation_role", "background_colossus")
	boss_visual.set_meta("target_player_height_ratio", 5.7)
	boss_visual.set_meta("minimum_visible_fraction", 0.8)
	boss_visual.set_meta("keep_gameplay_lanes_clear", true)
	if boss_visual is CollisionObject2D:
		(boss_visual as CollisionObject2D).collision_layer = 0
		(boss_visual as CollisionObject2D).collision_mask = 0
