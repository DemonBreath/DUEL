extends Node

@export var player_path: NodePath
@export var test_hat_id: String = "wizard_hat_01"

func _ready() -> void:
	var player: Node = get_node_or_null(player_path)
	print("TEST HAT PREP | player = ", player)

	if player == null:
		push_error("TestHatPrep: Missing player reference.")
		return

	if not player.has_method("get_player_inventory"):
		push_error("TestHatPrep: Player missing get_player_inventory().")
		return

	var inventory: Node = player.call("get_player_inventory")
	print("TEST HAT PREP | inventory = ", inventory)

	if inventory == null:
		push_error("TestHatPrep: Inventory is null.")
		return

	if not ItemDatabase.has_item_def(test_hat_id):
		push_error("TestHatPrep: Invalid test hat id: %s" % test_hat_id)
		return

	inventory.call("setup_from_data", {
		"owned_items": [
			test_hat_id
		],
		"equipped": {
			"head": test_hat_id
		}
	})

	print("TEST HAT PREP | equipped hat id = ", player.call("get_equipped_hat_id"))
	print("TEST HAT PREP | inventory data = ", inventory.call("to_data"))
