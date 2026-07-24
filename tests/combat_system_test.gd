extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := (load("res://scenes/maps/autumn_forest.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	await physics_frame

	var player := map.get_node("Player")
	var zone := map.get_node("ForestCombatZone")
	var slime := map.get_node("ForestCombatZone/Enemies/SlimeWest")
	_expect(player.is_in_group("Player"), "Player must be discoverable by combat AI.")
	_expect(zone.get("_remaining") == 2, "Autumn combat zone must start with two enemies.")

	var slime_start_health := int(slime.get("health"))
	var applied := int(slime.call("take_hit", 16, player.global_position, 0.0))
	_expect(applied == 15, "Enemy defense must reduce incoming player damage.")
	_expect(int(slime.get("health")) == slime_start_health - applied, "Enemy health must update after a hit.")

	var mana_before := int(player.get("mana"))
	_expect(bool(player.call("use_skill")), "Player should cast skill when enough mana is available.")
	_expect(int(player.get("mana")) == mana_before - int(player.get("skill_mana_cost")), "Skill must consume MP.")

	var health_before := int(player.get("health"))
	var player_damage := int(player.call("take_hit", 12, slime.global_position, 0.0))
	_expect(player_damage == 9, "Player defense must reduce incoming enemy damage.")
	_expect(int(player.get("health")) == health_before - player_damage, "Player health must update after enemy hit.")

	map.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
