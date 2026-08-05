extends SceneTree

class SuccessfulSaveService:
	extends SaveService

	func save_meta(_path: String, _data: Dictionary) -> bool:
		return true


class DamageTarget:
	extends Node2D

	var health := 500

	func take_damage(amount: int) -> int:
		var dealt := mini(health, maxi(0, amount))
		health -= dealt
		return dealt


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set("save_service", SuccessfulSaveService.new())
	game.call("_begin_autumn_run")
	game.set_process(false)
	var gifts := game.get("divine_gift_manager") as RefCounted
	for gift_id in ["resonant_grace", "prismatic_oath"]:
		for _level in 3:
			_expect(bool(gifts.call("add_or_upgrade", gift_id)), "Fusion materials must reach Lv.3.")
	game.call("_on_elite_defeated", Vector2.ZERO)
	await process_frame
	await process_frame

	var fusion_queue := game.get("growth_choice_queue") as GrowthChoiceQueue
	var fusion_page := fusion_queue.peek()
	var fusion_choices := fusion_page.get("choices", []) as Array
	var fusion_choice: Dictionary = {}
	for choice_variant in fusion_choices:
		if String((choice_variant as Dictionary).get("action", "")) == "divine_fusion":
			fusion_choice = (choice_variant as Dictionary).duplicate(true)
			break
	var growth_ui := game.get_open_ui("CardGrowthUI") as Control
	_expect(
		growth_ui != null
			and String(fusion_page.get("source", "")) == "elite"
			and not fusion_choice.is_empty(),
		"Only elite or boss loot may offer a Blessing merge."
	)
	var fusion_section := growth_ui.find_child("FusionSection", true, false) as Control
	var fusion_grid := growth_ui.find_child("FusionGrid", true, false) as GridContainer
	var fusion_profile := fusion_choice.get("background_attack", {}) as Dictionary
	var attack_preview := (load(
		"res://scenes/combat/vfx/EvolvedBackgroundAttack.tscn"
	) as PackedScene).instantiate()
	var energy_widths := attack_preview.call("get_energy_line_widths") as PackedFloat32Array
	var cadence_profile := attack_preview.call("get_cadence_profile") as Dictionary
	var supported_motifs := attack_preview.call("get_supported_blessing_motifs") as Array
	_expect(
		energy_widths.size() == 3
			and energy_widths[0] >= 24.0
			and energy_widths[1] >= 9.0
			and energy_widths[2] >= 4.0,
		"Fusion geometry must render as a thick glow, saturated energy body, and bright core instead of thin lines."
	)
	_expect(
		int(cadence_profile.get("beats", 0)) == 3
			and float(cadence_profile.get("duration", 0.0)) >= 0.9
			and bool(cadence_profile.get("sacred_halo", false)),
		"Fusion geometry must stage a readable three-beat sacred halo cadence."
	)
	_expect(
		supported_motifs.size() == 8,
		"The eight Blessings must have eight explicitly authored geometry motifs."
	)
	attack_preview.free()
	_expect(
		fusion_section != null
			and fusion_section.is_visible_in_tree()
			and fusion_grid != null
			and fusion_grid.get_child_count() > 0,
		"Eligible Blessing merges must appear in their own visible fusion section."
	)
	_expect(
		not fusion_profile.is_empty()
			and not String(fusion_profile.get("name", "")).is_empty()
			and float(fusion_profile.get("interval", 0.0)) > 0.0
			and (fusion_profile.get("geometry_modules", []) as Array).size() == 2
			and (fusion_profile.get("glow_colors", []) as Array).size() == 2,
		"Every evolved Blessing choice must preview its dedicated two-source geometric background auto-attack."
	)
	growth_ui.call("select_choice", String(fusion_choice.get("choice_id", "")))
	growth_ui.call("confirm_selected_choice")
	await process_frame
	var inventory := gifts.call("get_inventory") as Array
	_expect(
		inventory.size() == 1
			and String((inventory[0] as Dictionary).get("kind", "")) == "evolved",
		"Choosing elite loot merge must consume two Lv.3 Blessings and create one evolved Blessing."
	)
	var evolved := inventory[0] as Dictionary
	_expect(
		not (evolved.get("background_attack", {}) as Dictionary).is_empty()
			and (gifts.call("get_background_attack_profiles") as Array).size() == 1,
		"An evolved Blessing must retain an independently ticking background attack profile."
	)
	var run := game.get("run_state") as RunState
	var base_runtime_profile := game.call(
		"_runtime_background_attack_profile",
		evolved.get("background_attack", {}) as Dictionary
	) as Dictionary
	gifts.call("add_or_upgrade", "eternal_memory")
	gifts.call("add_or_upgrade", "radiant_mercy")
	run.temporary_buffs["combo_chain_count"] = 10
	var catastrophic_profile := game.call(
		"_runtime_background_attack_profile",
		evolved.get("background_attack", {}) as Dictionary
	) as Dictionary
	_expect(
		float(base_runtime_profile.get("size_scale", 0.0)) < 1.0
			and int(base_runtime_profile.get("instance_count", 0)) == 1
			and float(catastrophic_profile.get("size_scale", 0.0)) >= 2.4
			and int(catastrophic_profile.get("instance_count", 0)) >= 5
			and float(catastrophic_profile.get("rhythm_speed", 0.0)) >= 2.2
			and int(catastrophic_profile.get("target_count", 0)) > int(base_runtime_profile.get("target_count", 0))
			and float(catastrophic_profile.get("interval", 99.0)) < float(base_runtime_profile.get("interval", 0.0)),
		"A new fusion must begin as one small object, then Combo and supporting Blessings must make it larger, more numerous, and faster."
	)
	var inherited_base := game.call(
		"_build_background_attack_card", evolved.get("background_attack", {}) as Dictionary
	) as Dictionary
	run.temporary_buffs["infusion_effects"] = [{
		"infusion_id": "flame",
		"damage_bonus": 7,
		"burn_damage": 3,
		"burn_duration": 4.0,
		"remaining_seconds": 4.0,
	}]
	var inherited_infused := game.call(
		"_build_background_attack_card", evolved.get("background_attack", {}) as Dictionary
	) as Dictionary
	var base_effect := inherited_base.get("effect", {}) as Dictionary
	var infused_effect := inherited_infused.get("effect", {}) as Dictionary
	_expect(
		bool(inherited_infused.get("inherits_sword_soul", false))
			and int(infused_effect.get("amount", 0)) >= int(base_effect.get("amount", 0)) + 7
			and int(infused_effect.get("burn_damage", 0)) == 3
			and (infused_effect.get("elements", []) as Array).has("flame")
			and int(inherited_infused.get("cost", -1)) == 0,
		"Background attacks must inherit active Sword Soul damage and elemental effects without AP cost."
	)
	var target := DamageTarget.new()
	target.add_to_group("Enemies")
	(game.get("current_map") as Node).add_child(target)
	target.global_position = (game.get("player") as Node2D).global_position + Vector2(120.0, 0.0)
	var deck := game.get("deck_manager") as DeckManager
	var energy_before := deck.energy
	var basic_cooldown_before := float(game.get("_auto_attack_remaining"))
	game.call("_tick_evolved_background_attacks", 0.0)
	var attack_result := game.get("_last_background_attack_result") as Dictionary
	_expect(
		target.health < 500
			and int(attack_result.get("affected", 0)) == 1
			and bool(attack_result.get("inherits_sword_soul", false))
			and is_equal_approx(deck.energy, energy_before)
			and is_equal_approx(float(game.get("_auto_attack_remaining")), basic_cooldown_before),
		"The evolved background attack must deal real damage on its own timer without AP or Basic Attack cooldown cost."
	)
	target.queue_free()
	_expect(fusion_queue.is_empty() and not paused, "Finishing elite fusion must resume combat.")

	game.queue_free()
	await process_frame
	paused = false
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
