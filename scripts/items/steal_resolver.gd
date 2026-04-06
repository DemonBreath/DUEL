extends Node

func resolve_wagered_hat_steal(winner_inventory: Node, loser_inventory: Node) -> Dictionary:
	if winner_inventory == null or loser_inventory == null:
		return {
			"success": false,
			"reason": "missing_inventory_reference"
		}

	if not loser_inventory.has_method("get_equipped_item"):
		return {
			"success": false,
			"reason": "loser_missing_required_api"
		}

	if not winner_inventory.has_method("add_item"):
		return {
			"success": false,
			"reason": "winner_missing_required_api"
		}

	var stolen_item_id: String = str(loser_inventory.call("get_equipped_item", "head"))
	if stolen_item_id == "":
		return {
			"success": false,
			"reason": "no_wagered_hat"
		}

	var removed_ok: bool = false
	if loser_inventory.has_method("remove_item"):
		removed_ok = bool(loser_inventory.call("remove_item", stolen_item_id))

	if not removed_ok:
		return {
			"success": false,
			"reason": "failed_to_remove_from_loser",
			"item_id": stolen_item_id
		}

	var added_ok: bool = bool(winner_inventory.call("add_item", stolen_item_id))
	if not added_ok:
		return {
			"success": false,
			"reason": "failed_to_add_to_winner",
			"item_id": stolen_item_id
		}

	if loser_inventory.has_method("ensure_minimum_hat"):
		loser_inventory.call("ensure_minimum_hat")

	if loser_inventory.has_method("ensure_equipped_hat"):
		loser_inventory.call("ensure_equipped_hat")

	return {
		"success": true,
		"item_id": stolen_item_id,
		"slot": "head",
		"display_name": ItemDatabase.get_item_display_name(stolen_item_id),
		"rarity": ItemDatabase.get_item_rarity(stolen_item_id),
		"flavor_text": ItemDatabase.get_item_flavor_text(stolen_item_id)
	}
