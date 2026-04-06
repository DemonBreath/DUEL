extends Node

@export var winner_inventory_path: NodePath
@export var loser_inventory_path: NodePath
@export var hat_match_service_path: NodePath
@export var steal_resolver_path: NodePath
@export var hat_result_formatter_path: NodePath

func _ready() -> void:
	var winner_inventory: Node = get_node_or_null(winner_inventory_path)
	var loser_inventory: Node = get_node_or_null(loser_inventory_path)
	var hat_match_service: Node = get_node_or_null(hat_match_service_path)
	var steal_resolver: Node = get_node_or_null(steal_resolver_path)
	var hat_result_formatter: Node = get_node_or_null(hat_result_formatter_path)

	if winner_inventory == null or loser_inventory == null:
		push_error("TestHatMatchFlow: Missing inventory references.")
		return

	if hat_match_service == null or steal_resolver == null or hat_result_formatter == null:
		push_error("TestHatMatchFlow: Missing service references.")
		return

	winner_inventory.call("setup_from_data", {
		"owned_items": [
			"inferno_ring_01"
		],
		"equipped": {
			"head": "inferno_ring_01"
		}
	})

	loser_inventory.call("setup_from_data", {
		"owned_items": [],
		"equipped": {
			"head": ""
		}
	})

	var winner_prep: Dictionary = hat_match_service.call("prepare_player_for_match", winner_inventory)
	var loser_prep: Dictionary = hat_match_service.call("prepare_player_for_match", loser_inventory)

	print("WINNER PREP: ", winner_prep)
	print("LOSER PREP: ", loser_prep)

	var result: Dictionary = hat_match_service.call("resolve_match_winner", winner_inventory, loser_inventory, steal_resolver)
	print("MATCH RESULT: ", result)

	var win_text: String = str(hat_result_formatter.call("format_hat_win_text", result))
	print(win_text)
