extends Node

var player_name: String = "Player"

func set_player_name_value(new_name: String) -> void:
	var cleaned: String = new_name.strip_edges()

	if cleaned == "":
		player_name = "Player"
	else:
		player_name = cleaned.substr(0, 16)

	print("PLAYER NAME SET: ", player_name)

func get_player_name_value() -> String:
	return player_name
