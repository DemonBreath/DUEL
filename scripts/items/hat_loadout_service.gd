extends Node

func prepare_inventory_for_match(player_inventory: Node) -> Dictionary:
	if player_inventory == null:
		return {
			"success": false,
			"reason": "missing_inventory"
		}

	if not player_inventory.has_method("ensure_minimum_hat"):
		return {
			"success": false,
			"reason": "missing_ensure_minimum_hat"
		}

	if not player_inventory.has_method("ensure_equipped_hat"):
		return {
			"success": false,
			"reason": "missing_ensure_equipped_hat"
		}

	player_inventory.call("ensure_minimum_hat")
	var equipped_ok: bool = bool(player_inventory.call("ensure_equipped_hat"))

	if not equipped_ok:
		return {
			"success": false,
			"reason": "failed_to_equip_hat"
		}

	var equipped_hat_id := ""
	if player_inventory.has_method("get_equipped_item"):
		equipped_hat_id = str(player_inventory.call("get_equipped_item", "head"))

	return {
		"success": true,
		"equipped_hat_id": equipped_hat_id,
		"display_name": ItemDatabase.get_item_display_name(equipped_hat_id),
		"rarity": ItemDatabase.get_item_rarity(equipped_hat_id),
		"flavor_text": ItemDatabase.get_item_flavor_text(equipped_hat_id)
	}

func get_equipped_hat_summary(player_inventory: Node) -> Dictionary:
	if player_inventory == null:
		return {
			"success": false,
			"reason": "missing_inventory"
		}

	if not player_inventory.has_method("get_equipped_item"):
		return {
			"success": false,
			"reason": "missing_get_equipped_item"
		}

	var item_id: String = str(player_inventory.call("get_equipped_item", "head"))
	if item_id == "":
		return {
			"success": false,
			"reason": "no_equipped_hat"
		}

	return {
		"success": true,
		"item_id": item_id,
		"display_name": ItemDatabase.get_item_display_name(item_id),
		"rarity": ItemDatabase.get_item_rarity(item_id),
		"flavor_text": ItemDatabase.get_item_flavor_text(item_id)
	}
