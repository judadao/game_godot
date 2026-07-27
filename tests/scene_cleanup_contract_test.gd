extends SceneTree

const RETIRED_SCENE_PATHS: Array[String] = [
	"res://scenes/props/buildings/NoticeBoard.tscn",
	"res://scenes/props/buildings/TownPortal.tscn",
	"res://scenes/props/buildings/TownWell.tscn",
	"res://scenes/props/town/BarrelStack.tscn",
	"res://scenes/props/town/Bench.tscn",
	"res://scenes/props/town/Crates.tscn",
	"res://scenes/props/town/CrossroadSign.tscn",
	"res://scenes/props/town/EastTree.tscn",
	"res://scenes/props/town/Fence.tscn",
	"res://scenes/props/town/FlowerBed.tscn",
	"res://scenes/props/town/Lamp.tscn",
	"res://scenes/props/town/MarketCart.tscn",
	"res://scenes/combat/SkillWave.tscn",
	"res://scenes/ui/hud/HUDNavigationGroup.tscn",
	"res://scenes/ui/hud/HUDCompass.tscn",
	"res://scenes/ui/hud/HUDMinimap.tscn",
	"res://scenes/ui/hud/HUDStatusBar.tscn",
	"res://scenes/props/dungeon_props_showcase.tscn",
]

var _failures := 0


func _init() -> void:
	for scene_path in RETIRED_SCENE_PATHS:
		_expect(
			not ResourceLoader.exists(scene_path),
			"Retired unreferenced scene must stay removed: %s." % scene_path
		)
	quit(0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
