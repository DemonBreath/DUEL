extends Node

func prepare_player_for_match(player_inventory: Node) -> Dictionary:
	if player_inventory == null:
		return {
			"success": false,
			"reason": "missing_inventory"
		}

	if not player_inventory.has_method("ensure_minimum_hat"):
		return {
			"success": false,
			"reason": "inventory_missing_ensure_minimum_hat"
		}

	if not player_inventory.has_method("ensure_equipped_hat"):
		return {
			"success": false,
			"reason": "inventory_missing_ensure_equipped_hat"
		}

	player_inventory.call("ensure_minimum_hat")
	var equipped_ok: bool = bool(player_inventory.call("ensure_equipped_hat"))

	if not equipped_ok:
		return {
			"success": false,
			"reason": "failed_to_equip_hat"
		}

	var equipped_hat_id: String = ""
	if player_inventory.has_method("get_equipped_item"):
		equipped_hat_id = str(player_inventory.call("get_equipped_item", "head"))

	return {
		"success": true,
		"equipped_hat_id": equipped_hat_id,
		"display_name": ItemDatabase.get_item_display_name(equipped_hat_id),
		"rarity": ItemDatabase.get_item_rarity(equipped_hat_id),
		"flavor_text": ItemDatabase.get_item_flavor_text(equipped_hat_id)
	}


func resolve_match_winner(winner_inventory: Node, loser_inventory: Node, steal_resolver: Node) -> Dictionary:
	if winner_inventory == null or loser_inventory == null or steal_resolver == null:
		return {
			"success": false,
			"reason": "missing_required_reference"
		}

	if not steal_resolver.has_method("resolve_wagered_hat_steal"):
		return {
			"success": false,
			"reason": "steal_resolver_missing_api"
		}

	var result: Dictionary = steal_resolver.call("resolve_wagered_hat_steal", winner_inventory, loser_inventory)
	return result
