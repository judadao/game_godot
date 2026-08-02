extends SceneTree

const PORTRAIT_SCENE := "res://scenes/ui/town/TownNPCPortrait.tscn"
const PORTRAIT_SCRIPT := "res://scripts/ui/town/town_npc_portrait.gd"
const CHARACTER_TEXTURE_ROOT := "res://assets/town/npc/characters/"
const UI_PORTRAITS := {
	"res://scenes/ui/town/MaterialYardUI.tscn": "ShopkeeperPortrait",
	"res://scenes/ui/town/PlayerBlacksmithUI.tscn": "ProtagonistPortrait",
	"res://scenes/ui/town/TownHallUI.tscn": "MayorPortrait",
	"res://scenes/ui/shop/ShopUI.tscn": "MerchantPortrait",
}

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(PORTRAIT_SCENE) as PackedScene
	_expect(packed != null, "Town must provide one reusable animated half-body NPC portrait.")
	if packed != null:
		var portrait := packed.instantiate() as Control
		root.add_child(portrait)
		_expect(
			portrait.get_script() != null and portrait.get_script().resource_path == PORTRAIT_SCRIPT,
			"Town portrait must use the reusable animation script."
		)
		_expect(portrait.clip_contents, "Half-body portrait must clip inside its shared frame.")
		_expect(portrait.has_method("set_character_texture"), "Portrait must support shop-context character changes.")
		_expect(portrait.has_method("play_state"), "Portrait must expose animated expression states.")
		portrait.queue_free()
	for scene_path in UI_PORTRAITS:
		_assert_ui_portrait(String(scene_path), String(UI_PORTRAITS[scene_path]))
	_assert_equipment_shop_identity()
	_finish()


func _assert_ui_portrait(scene_path: String, portrait_name: String) -> void:
	var ui := (load(scene_path) as PackedScene).instantiate() as Control
	root.add_child(ui)
	var portrait := ui.find_child(portrait_name, true, false) as Control
	_expect(portrait != null, "%s must retain %s." % [scene_path, portrait_name])
	if portrait != null:
		_expect(
			portrait.scene_file_path == PORTRAIT_SCENE,
			"%s must instance the animated half-body portrait component." % portrait_name
		)
		var texture: Texture2D = portrait.get("character_texture")
		_expect(
			texture != null and texture.resource_path.begins_with(CHARACTER_TEXTURE_ROOT),
			"%s must use a new NPC character cutout." % portrait_name
		)
		portrait.call("play_state", &"chat")
		portrait.call("advance_animation", 0.4)
		_expect(portrait.call("get_active_state") == &"chat", "%s must animate while its UI is open." % portrait_name)
	ui.queue_free()


func _assert_equipment_shop_identity() -> void:
	var shop := (load("res://scenes/ui/shop/ShopUI.tscn") as PackedScene).instantiate() as Control
	root.add_child(shop)
	shop.call("set_shop_context", &"equipment_blueprint_shop")
	var role := shop.find_child("SectionLabel", true, false) as Label
	var identity := shop.find_child("IdentityLabel", true, false) as Label
	_expect(
		role != null and role.text == "ARCANE DRAFTSMAN"
			and identity != null and identity.text == "Professor Orin",
		"Equipment Blueprint portrait identity must match the scientist character."
	)
	shop.queue_free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: Town NPC portrait animation contract")
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
