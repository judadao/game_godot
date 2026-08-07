extends SceneTree

const BOSS_SCENE := preload("res://scenes/monsters/AutumnSmokeOniBoss.tscn")
const REQUIRED_ANIMATIONS := [
	&"idle", &"six_arm_slash", &"cross_execution",
	&"skull_flame_summon", &"phase_shift", &"hurt", &"death",
]
const REQUIRED_ASSETS := [
	"res://assets/enemies/bosses/generated/six_arm_oni_upper_skull_kabuto_v3.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_lower_jaw_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_skeletal_torso_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_skeletal_smoke_pelvis_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_left_upper_arm_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_left_forearm_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_left_hand_katana_up_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_right_upper_arm_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_right_forearm_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_right_hand_katana_up_v4.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_left_hand_katana_down_v3.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_right_hand_katana_down_v3.png",
	"res://assets/enemies/bosses/generated/six_arm_oni_cyan_flame_effects_v3.png",
]

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for path in REQUIRED_ASSETS:
		_expect(ResourceLoader.exists(path), "Six-arm blue-flame boss animation part must exist: %s." % path)
	var boss := BOSS_SCENE.instantiate()
	root.add_child(boss)
	await process_frame
	_expect(boss.has_method("play_boss_animation"), "Blue-flame boss must expose named animation playback.")
	for animation_id in REQUIRED_ANIMATIONS:
		_expect(bool(boss.call("play_boss_animation", animation_id)), "Boss animation must play: %s." % animation_id)
		boss.call("advance_boss_animation", 0.35)
		var snapshot := boss.call("get_boss_animation_snapshot") as Dictionary
		_expect(StringName(snapshot.get("animation", "")) == animation_id, "Boss snapshot must identify %s." % animation_id)
	boss.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
