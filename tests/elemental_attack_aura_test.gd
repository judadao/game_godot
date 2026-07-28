extends SceneTree

const AURA_SCENE_PATH := "res://scenes/combat/vfx/ElementalAttackAura.tscn"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(AURA_SCENE_PATH) as PackedScene
	_expect(packed != null, "Elemental attack aura scene must load from its reusable combat path.")
	if packed == null:
		_finish()
		return

	var host := Node2D.new()
	host.position = Vector2(120.0, 80.0)
	root.add_child(host)
	var aura := packed.instantiate() as Node2D
	host.add_child(aura)
	await process_frame

	_expect(aura != null, "Elemental attack aura must use a Node2D root.")
	_expect(aura.position == Vector2.ZERO, "Aura must inherit its host transform without a fixed world offset.")
	_expect(
		aura.has_method("configure")
			and aura.has_method("get_element_layer_count")
			and aura.has_method("get_intensity")
			and aura.has_method("is_active"),
		"Aura must expose its reusable configuration and observable state API."
	)

	aura.call("configure", ["flame", "flame", "unknown"], 0)
	_expect(int(aura.call("get_element_layer_count")) == 1, "Duplicate and unsupported elements must not add visual layers.")
	_expect(int(aura.call("get_intensity")) == 1, "Intensity must clamp to the minimum supported level.")
	_expect(bool(aura.call("is_active")), "A supported configured element must activate the aura.")
	_expect(int(aura.call("get_particle_budget")) == 17, "Minimum flame intensity must use its bounded particle budget.")
	_expect(
		(aura.get_node("FireLayer") as Node2D).visible
			and not (aura.get_node("IceLayer") as Node2D).visible,
		"Flame configuration must enable only the authored fire layer."
	)
	host.position += Vector2(35.0, -12.0)
	_expect(aura.global_position == host.global_position, "Aura must follow its parent transform without polling the SceneTree.")

	aura.call("configure", ["frost", "flame"], 99)
	_expect(int(aura.call("get_element_layer_count")) == 2, "Fire and frost must stack as two independent visual layers.")
	_expect(int(aura.call("get_intensity")) == 5, "Intensity must clamp to the performance-safe maximum.")
	_expect(int(aura.call("get_particle_budget")) == 155, "Maximum dual-element intensity must retain a deterministic particle cap.")
	_expect(
		(aura.get_node("FireLayer/FlameTongue") as GPUParticles2D).emitting
			and (aura.get_node("FireLayer/Sparks") as GPUParticles2D).emitting,
		"Active fire must emit both flame tongues and sparks."
	)
	_expect(
		(aura.get_node("IceLayer/FrostCrystals") as GPUParticles2D).emitting
			and (aura.get_node("IceLayer/ColdMist") as GPUParticles2D).emitting
			and (aura.get_node("IceLayer/FrostArc") as Line2D).visible,
		"Active frost must emit crystals and cold mist with a visible orbiting arc."
	)

	aura.call("set_active", false)
	_expect(not bool(aura.call("is_active")), "Aura must support pausing without freeing its reusable node.")
	_expect(
		not (aura.get_node("FireLayer/FlameTongue") as GPUParticles2D).emitting
			and not (aura.get_node("IceLayer/ColdMist") as GPUParticles2D).emitting,
		"Pausing must stop particle emission."
	)
	aura.call("set_active", true)
	_expect(bool(aura.call("is_active")), "A paused configured aura must be reusable.")
	aura.call("set_lifetime", 0.04)
	aura.call("set_active", true)
	await create_timer(0.08).timeout
	_expect(not bool(aura.call("is_active")), "A finite lifetime must stop reusable emission without freeing the aura.")

	aura.call("configure", [], 3)
	_expect(
		not bool(aura.call("is_active"))
			and int(aura.call("get_element_layer_count")) == 0,
		"Empty configuration must deactivate and clear every visual layer."
	)

	host.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: reusable fire and frost attack aura contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
