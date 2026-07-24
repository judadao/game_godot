extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_scene := load("res://scenes/game/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var shop_scene := load("res://scenes/ui/ShopUI.tscn") as PackedScene
	var shop := game.call("open_ui", "ShopUI", shop_scene) as Control
	await process_frame
	var catalog: Array = game.call("_catalog_for_shop", &"general_store")
	var potion := (catalog[0] as Dictionary).duplicate(true)

	var starting_wallet := int(game.get("wallet_gold"))
	var starting_owned := int((game.get("player_inventory") as Dictionary).get("potion", 0))
	var starting_stock := int(potion.get("stock", 0))
	game.call("_on_shop_transaction_confirmed", potion, 2, "buy", shop, &"general_store")
	var after_buy_catalog: Array = game.call("_catalog_for_shop", &"general_store")
	_expect(int(game.get("wallet_gold")) == starting_wallet - 50, "Buy must deduct wallet gold.")
	_expect(
		int((game.get("player_inventory") as Dictionary).get("potion", 0)) == starting_owned + 2,
		"Buy must add inventory quantity."
	)
	_expect(int((after_buy_catalog[0] as Dictionary).get("stock", 0)) == starting_stock - 2, "Buy must reduce stock.")

	game.call("_on_shop_transaction_confirmed", after_buy_catalog[0], 1, "sell", shop, &"general_store")
	var after_sell_catalog: Array = game.call("_catalog_for_shop", &"general_store")
	_expect(int(game.get("wallet_gold")) == starting_wallet - 38, "Sell must credit the sell price.")
	_expect(
		int((game.get("player_inventory") as Dictionary).get("potion", 0)) == starting_owned + 1,
		"Sell must remove inventory quantity."
	)
	_expect(int((after_sell_catalog[0] as Dictionary).get("stock", 0)) == starting_stock - 1, "Sell must return stock.")

	var first_row := shop.get_node(
		"CenterContainer/ShopWindow/WindowMargin/WindowLayout/Content/ItemListPanel/ItemListLayout/Row01"
	) as Button
	_expect(not first_row.focus_neighbor_right.is_empty(), "Item rows need directional focus navigation.")
	game.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

var _failures := 0

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
