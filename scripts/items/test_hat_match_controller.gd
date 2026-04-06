extends Node

@export var player_a_path: NodePath
@export var player_b_path: NodePath
@export var hat_match_controller_path: NodePath

func _ready() -> void:
	var player_a: Node = get_node_or_null(player_a_path)
	var player_b: Node = get_node_or_null(player_b_path)
	var hat_match_controller: Node = get_node_or_null(hat_match_controller_path)

	if player_a == null or player_b == null:
		push_error("TestHatMatchController: Missing player references.")
		return

	if hat_match_controller == null:
		push_error("TestHatMatchController: Missing HatMatchController reference.")
		return

	var inv_a: Node = player_a.call("get_player_inventory")
	var inv_b: Node = player_b.call("get_player_inventory")

	inv_a.call("setup_from_data", {
		"owned_items": [
			"inferno_ring_01"
		],
		"equipped": {
			"head": "inferno_ring_01"
		}
	})

	inv_b.call("setup_from_data", {
		"owned_items": [],
		"equipped": {
			"head": ""
		}
	})

	var prep_result: Dictionary = hat_match_controller.call("prepare_players_for_match", player_a, player_b)
	print("PREP RESULT: ", prep_result)

	var match_result: Dictionary = hat_match_controller.call("resolve_match_result", player_a, player_b)
	print("MATCH RESULT: ", match_result)

	var win_text: String = str(hat_match_controller.call("get_win_result_text", match_result))
	var loss_text: String = str(hat_match_controller.call("get_loss_result_text", match_result))

	print("WIN TEXT:\n", win_text)
	print("LOSS TEXT:\n", loss_text)
