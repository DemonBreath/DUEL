extends Node

@export var player_path: NodePath
@export var steal_resolver_path: NodePath

func _ready() -> void:
	var player: Node = get_node_or_null(player_path)
	var steal_resolver: Node = get_node_or_null(steal_resolver_path)

	print("TEST HAT STEAL | player = ", player)
	print("TEST HAT STEAL | steal_resolver = ", steal_resolver)

	if player == null:
		push_error("TestHatSteal: Missing player reference.")
		return

	if steal_resolver == null:
		push_error("TestHatSteal: Missing StealResolver reference.")
		return

	if not player.has_method("get_player_inventory"):
		push_error("TestHatSteal: Player missing get_player_inventory().")
		return

	var winner_inventory: Node = player.call("get_player_inventory")
	if winner_inventory == null:
		push_error("TestHatSteal: Winner inventory is null.")
		return

	var loser_inventory := Node.new()
	loser_inventory.set_script(load("res://scripts/items/player_inventory.gd"))

	if loser_inventory == null:
		push_error("TestHatSteal: Failed to create loser inventory.")
		return

	add_child(loser_inventory)

	winner_inventory.call("setup_from_data", {
		"owned_items": [
			"plastic_hat_01"
		],
		"equipped": {
			"head": "plastic_hat_01"
		}
	})

	loser_inventory.call("setup_from_data", {
		"owned_items": [
			"skull_hat_01"
		],
		"equipped": {
			"head": "skull_hat_01"
		}
	})

	print("TEST HAT STEAL | winner before = ", winner_inventory.call("to_data"))
	print("TEST HAT STEAL | loser before = ", loser_inventory.call("to_data"))

	var result: Dictionary = steal_resolver.call("resolve_wagered_hat_steal", winner_inventory, loser_inventory)

	print("TEST HAT STEAL | result = ", result)
	print("TEST HAT STEAL | winner after = ", winner_inventory.call("to_data"))
	print("TEST HAT STEAL | loser after = ", loser_inventory.call("to_data"))
