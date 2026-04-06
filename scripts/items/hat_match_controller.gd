extends Node

@export var hat_loadout_service_path: NodePath
@export var steal_resolver_path: NodePath
@export var hat_result_formatter_path: NodePath

var hat_loadout_service: Node = null
var steal_resolver: Node = null
var hat_result_formatter: Node = null

func _ready() -> void:
	hat_loadout_service = get_node_or_null(hat_loadout_service_path)
	steal_resolver = get_node_or_null(steal_resolver_path)
	hat_result_formatter = get_node_or_null(hat_result_formatter_path)

func prepare_players_for_match(player_a: Node, player_b: Node) -> Dictionary:
	var result := {
		"success": false,
		"player_a": {},
		"player_b": {}
	}

	if player_a == null or player_b == null:
		result["reason"] = "missing_player_reference"
		return result

	if hat_loadout_service == null:
		result["reason"] = "missing_hat_loadout_service"
		return result

	if not player_a.has_method("get_player_inventory") or not player_b.has_method("get_player_inventory"):
		result["reason"] = "player_missing_inventory_api"
		return result

	var inventory_a: Node = player_a.call("get_player_inventory")
	var inventory_b: Node = player_b.call("get_player_inventory")

	var prep_a: Dictionary = hat_loadout_service.call("prepare_inventory_for_match", inventory_a)
	var prep_b: Dictionary = hat_loadout_service.call("prepare_inventory_for_match", inventory_b)

	result["player_a"] = prep_a
	result["player_b"] = prep_b
	result["success"] = bool(prep_a.get("success", false)) and bool(prep_b.get("success", false))

	if not result["success"]:
		result["reason"] = "one_or_more_players_failed_match_prep"

	return result

func resolve_match_result(winner_player: Node, loser_player: Node) -> Dictionary:
	var result := {
		"success": false
	}

	if winner_player == null or loser_player == null:
		result["reason"] = "missing_player_reference"
		return result

	if steal_resolver == null:
		result["reason"] = "missing_steal_resolver"
		return result

	if not winner_player.has_method("get_player_inventory") or not loser_player.has_method("get_player_inventory"):
		result["reason"] = "player_missing_inventory_api"
		return result

	var winner_inventory: Node = winner_player.call("get_player_inventory")
	var loser_inventory: Node = loser_player.call("get_player_inventory")

	result = steal_resolver.call("resolve_wagered_hat_steal", winner_inventory, loser_inventory)
	return result

func get_win_result_text(result_data: Dictionary) -> String:
	if hat_result_formatter == null:
		return "No result formatter assigned."

	return str(hat_result_formatter.call("format_hat_win_text", result_data))

func get_loss_result_text(result_data: Dictionary) -> String:
	if hat_result_formatter == null:
		return "No result formatter assigned."

	return str(hat_result_formatter.call("format_hat_loss_text", result_data))
