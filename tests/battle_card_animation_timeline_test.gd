extends SceneTree

const CARD_PATH := "res://scenes/ui/autumn/AutumnBattleCard.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CARD_PATH) as PackedScene
	_expect(packed != null, "戰鬥卡場景必須可載入。")
	if packed == null:
		quit(1)
		return

	var first := packed.instantiate() as Control
	first.size = Vector2(240.0, 300.0)
	root.add_child(first)
	await process_frame
	await create_timer(0.14).timeout

	var second := packed.instantiate() as Control
	second.size = Vector2(240.0, 300.0)
	root.add_child(second)
	await process_frame
	await process_frame

	var first_sun := first.get_node("CardContent/SunWave") as Control
	var second_sun := second.get_node("CardContent/SunWave") as Control
	var first_frame := first.get_node("CardContent/TarotFrameOverlay") as Control
	var second_frame := second.get_node("CardContent/TarotFrameOverlay") as Control
	_expect(
		bool((first_sun.call("get_visualizer_state") as Dictionary).get("seamless_wrap", false))
			and bool((first_frame.call("get_geometry_state") as Dictionary).get("seamless_wrap", false)),
		"日芒與金色外框必須宣告無跳點的循環契約。"
	)
	_expect(
		first_sun.has_method("get_timeline_phase")
			and second_sun.has_method("get_timeline_phase")
			and _angular_distance(
				float(first_sun.call("get_timeline_phase")),
				float(second_sun.call("get_timeline_phase")),
				TAU
			) <= 0.05,
		"稍後重建的日芒必須接續全域相位，不能從零重播。"
	)
	_expect(
		first_frame.has_method("get_timeline_phase")
			and second_frame.has_method("get_timeline_phase")
			and _angular_distance(
				float(first_frame.call("get_timeline_phase")),
				float(second_frame.call("get_timeline_phase")),
				1.0
			) <= 0.02,
		"稍後重建的金色外框充能必須接續全域相位，不能從零重播。"
	)

	first.queue_free()
	second.queue_free()
	if _failures == 0:
		print("PASS: Battle card sunburst and frame use a continuous global timeline")
	quit(1 if _failures > 0 else 0)


func _angular_distance(first: float, second: float, period: float) -> float:
	var difference := absf(first - second)
	return minf(difference, period - difference)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
