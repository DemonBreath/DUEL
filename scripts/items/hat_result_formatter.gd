extends Node

func format_hat_win_text(result: Dictionary) -> String:
	if not bool(result.get("success", false)):
		return "No hat was won."

	var display_name: String = str(result.get("display_name", "Unknown Hat"))
	var rarity: String = str(result.get("rarity", "common")).capitalize()
	var flavor_text: String = str(result.get("flavor_text", ""))

	var text := "You won: %s\nRarity: %s" % [display_name, rarity]

	if flavor_text != "":
		text += "\n%s" % flavor_text

	return text


func format_hat_loss_text(result: Dictionary) -> String:
	if not bool(result.get("success", false)):
		return "No hat was lost."

	var display_name: String = str(result.get("display_name", "Unknown Hat"))
	var rarity: String = str(result.get("rarity", "common")).capitalize()
	var flavor_text: String = str(result.get("flavor_text", ""))

	var text := "You lost: %s\nRarity: %s" % [display_name, rarity]

	if flavor_text != "":
		text += "\n%s" % flavor_text

	return text
