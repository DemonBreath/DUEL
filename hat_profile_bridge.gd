extends Node

const DEFAULT_HAT_DATA := {
	"owned_items": [],
	"equipped": {
		"head": ""
	}
}

func get_hat_data_from_profile(profile_data: Dictionary) -> Dictionary:
	if not profile_data.has("hat_inventory"):
		return DEFAULT_HAT_DATA.duplicate(true)

	var hat_data: Variant = profile_data.get("hat_inventory", {})
	if typeof(hat_data) != TYPE_DICTIONARY:
		return DEFAULT_HAT_DATA.duplicate(true)

	var result: Dictionary = DEFAULT_HAT_DATA.duplicate(true)
	var incoming: Dictionary = hat_data

	var owned_items: Array = incoming.get("owned_items", [])
	result["owned_items"] = []
	for item in owned_items:
		result["owned_items"].append(str(item))

	var equipped: Dictionary = incoming.get("equipped", {})
	result["equipped"]["head"] = str(equipped.get("head", ""))

	return result

func apply_hat_data_to_inventory(player_inventory: Node, profile_data: Dictionary) -> bool:
	if player_inventory == null:
		push_warning("HatProfileBridge: Missing player_inventory.")
		return false

	if not player_inventory.has_method("setup_from_data"):
		push_warning("HatProfileBridge: player_inventory missing setup_from_data.")
		return false

	var hat_data: Dictionary = get_hat_data_from_profile(profile_data)
	player_inventory.call("setup_from_data", hat_data)
	return true

func write_inventory_to_profile(player_inventory: Node, profile_data: Dictionary) -> Dictionary:
	var result: Dictionary = profile_data.duplicate(true)

	if player_inventory == null:
		push_warning("HatProfileBridge: Missing player_inventory.")
		if not result.has("hat_inventory"):
			result["hat_inventory"] = DEFAULT_HAT_DATA.duplicate(true)
		return result

	if not player_inventory.has_method("to_data"):
		push_warning("HatProfileBridge: player_inventory missing to_data.")
		if not result.has("hat_inventory"):
			result["hat_inventory"] = DEFAULT_HAT_DATA.duplicate(true)
		return result

	result["hat_inventory"] = player_inventory.call("to_data")
	return result

func ensure_profile_has_hat_inventory(profile_data: Dictionary) -> Dictionary:
	var result: Dictionary = profile_data.duplicate(true)

	if not result.has("hat_inventory"):
		result["hat_inventory"] = DEFAULT_HAT_DATA.duplicate(true)
		return result

	var hat_inventory: Variant = result.get("hat_inventory", {})
	if typeof(hat_inventory) != TYPE_DICTIONARY:
		result["hat_inventory"] = DEFAULT_HAT_DATA.duplicate(true)
		return result

	var hat_dict: Dictionary = hat_inventory

	if not hat_dict.has("owned_items"):
		hat_dict["owned_items"] = []

	if not hat_dict.has("equipped"):
		hat_dict["equipped"] = { "head": "" }

	var equipped: Variant = hat_dict.get("equipped", {})
	if typeof(equipped) != TYPE_DICTIONARY:
		hat_dict["equipped"] = { "head": "" }
	else:
		var equipped_dict: Dictionary = equipped
		if not equipped_dict.has("head"):
			equipped_dict["head"] = ""
		hat_dict["equipped"] = equipped_dict

	result["hat_inventory"] = hat_dict
	return result
