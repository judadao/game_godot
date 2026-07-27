extends SceneTree

const REGISTRY_PATH := "res://scripts/systems/map_registry.gd"
const GAME_SCRIPT_PATH := "res://scripts/managers/game.gd"
const MAP_CASES: Array[Dictionary] = [
	{
		"canonical": "res://scenes/maps/town.tscn",
		"authoritative": "res://scenes/maps/town/TownMap.tscn",
	},
	{
		"canonical": "res://scenes/maps/autumn_forest.tscn",
		"authoritative": "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn",
	},
	{
		"canonical": "res://scenes/maps/crystal_caves.tscn",
		"authoritative": "res://scenes/maps/layouts/CrystalCavesLayout.tscn",
	},
	{
		"canonical": "res://scenes/maps/forbidden_graveyard.tscn",
		"authoritative": "res://scenes/maps/layouts/ForbiddenGraveyardLayout.tscn",
	},
]
const UNKNOWN_PATH := "res://scenes/maps/unknown_map.tscn"
const LEGACY_AUTUMN_TREE_PATH := "res://scenes/maps/autumn_tree/AutumnTreeMap.tscn"
const LEGACY_AUTUMN_TREE_HELPERS_PATH := "res://scenes/maps/autumn_tree/editor/AutumnTreeEditorHelpers.tscn"
const AUTUMN_CANONICAL_PATH := "res://scenes/maps/autumn_forest.tscn"
const AUTUMN_AUTHORITATIVE_PATH := "res://scenes/maps/autumn_battle/AutumnBattleMapV2.tscn"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(
		ResourceLoader.exists(REGISTRY_PATH),
		"MapRegistry script must exist as the owner of map path resolution."
	)
	if not ResourceLoader.exists(REGISTRY_PATH):
		quit(1)
		return

	var registry_script := load(REGISTRY_PATH) as GDScript
	_expect(registry_script != null, "MapRegistry script must load.")
	if registry_script == null:
		quit(1)
		return
	var registry := registry_script.new() as RefCounted

	for map_case in MAP_CASES:
		var canonical := String(map_case["canonical"])
		var authoritative := String(map_case["authoritative"])
		_expect_equal(
			registry.call("resolve", canonical),
			authoritative,
			"Canonical map path must resolve to its authoritative scene."
		)
		_expect_equal(
			registry.call("resolve", authoritative),
			authoritative,
			"Authoritative map path must remain authoritative when resolved."
		)
		_expect_equal(
			registry.call("canonical", authoritative),
			canonical,
			"Authoritative map path must recover its canonical identity."
		)
		_expect_equal(
			registry.call("canonical", canonical),
			canonical,
			"Canonical map identity must remain canonical."
		)
		_expect(
			bool(registry.call("matches", authoritative, canonical)),
			"Authoritative map path must match its canonical identity."
		)
		_expect(
			bool(registry.call("matches", canonical, canonical)),
			"Canonical map path must match its own canonical identity."
		)

	_expect_equal(
		registry.call("resolve", UNKNOWN_PATH),
		UNKNOWN_PATH,
		"Unknown map paths must pass through resolution unchanged."
	)
	_expect_equal(
		registry.call("canonical", UNKNOWN_PATH),
		UNKNOWN_PATH,
		"Unknown map paths must retain their own canonical identity."
	)
	_expect_equal(
		registry.call("resolve", ""),
		"",
		"Empty map paths must pass through resolution unchanged."
	)
	_expect_equal(
		registry.call("canonical", ""),
		"",
		"Empty map paths must pass through canonicalization unchanged."
	)
	_expect_equal(
		registry.call("canonical", LEGACY_AUTUMN_TREE_PATH),
		AUTUMN_CANONICAL_PATH,
		"Legacy Autumn Tree saves must migrate to the Autumn canonical identity."
	)
	_expect_equal(
		registry.call("resolve", LEGACY_AUTUMN_TREE_PATH),
		AUTUMN_AUTHORITATIVE_PATH,
		"Legacy Autumn Tree saves must resolve to Autumn Battle V2."
	)
	_expect(
		bool(registry.call("matches", LEGACY_AUTUMN_TREE_PATH, AUTUMN_CANONICAL_PATH)),
		"Legacy Autumn Tree saves must match the Autumn canonical identity."
	)
	_expect(
		not ResourceLoader.exists(LEGACY_AUTUMN_TREE_PATH),
		"The legacy Autumn Tree scene must remain removed after its path is migrated."
	)
	_expect(
		not ResourceLoader.exists(LEGACY_AUTUMN_TREE_HELPERS_PATH),
		"The orphaned legacy Autumn Tree editor helpers must remain removed."
	)
	_expect(
		not bool(registry.call(
			"matches",
			String(MAP_CASES[0]["authoritative"]),
			String(MAP_CASES[1]["canonical"])
		)),
		"Different map identities must not match."
	)
	_expect(
		not bool(registry.call(
			"matches",
			String(MAP_CASES[0]["authoritative"]),
			String(MAP_CASES[0]["authoritative"])
		)),
		"Map matching must require a canonical comparison argument."
	)

	_test_game_compatibility_wrappers()
	registry = null
	quit(0 if _failures == 0 else 1)


func _test_game_compatibility_wrappers() -> void:
	var game_script := load(GAME_SCRIPT_PATH) as GDScript
	_expect(game_script != null, "Game script must load for compatibility coverage.")
	if game_script == null:
		return
	var game: Node = game_script.new()

	for index in MAP_CASES.size():
		var map_case := MAP_CASES[index]
		var canonical := String(map_case["canonical"])
		var authoritative := String(map_case["authoritative"])
		var other_canonical := String(MAP_CASES[(index + 1) % MAP_CASES.size()]["canonical"])
		_expect_equal(
			game.call("_resolve_main_scene_path", canonical),
			authoritative,
			"Game main-scene compatibility wrapper must delegate resolution."
		)
		_expect_equal(
			game.call("_resolve_layout_scene_path", canonical),
			authoritative,
			"Game layout compatibility wrapper must delegate resolution."
		)
		_expect_equal(
			game.call("_resolve_layout_scene_path", authoritative),
			authoritative,
			"Game layout compatibility wrapper must keep authoritative paths unchanged."
		)
		_expect_equal(
			game.call("_canonical_map_scene_path", authoritative),
			canonical,
			"Game canonical compatibility wrapper must delegate canonicalization."
		)

		var current_map := (load(authoritative) as PackedScene).instantiate()
		game.set("current_map", current_map)
		_expect(
			bool(game.call("_current_map_matches", canonical)),
			"Game current-map compatibility wrapper must match canonical identity."
		)
		_expect(
			not bool(game.call("_current_map_matches", other_canonical)),
			"Game current-map compatibility wrapper must reject another identity."
		)
		_expect(
			not bool(game.call("_current_map_matches", authoritative)),
			"Game current-map compatibility wrapper must not canonicalize its comparison argument."
		)
		game.set("current_map", null)
		current_map.free()

	game.set("current_map", null)
	_expect(
		not bool(game.call("_current_map_matches", String(MAP_CASES[0]["canonical"]))),
		"Game current-map compatibility wrapper must reject a missing map."
	)
	game.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s Expected %s, got %s." % [message, expected, actual])
