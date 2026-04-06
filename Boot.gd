extends Node

@export var client_scene_path: String = "res://title_screen.tscn"
@export var server_scene_path: String = "res://arena.tscn"
@export var server_port: int = 8910

func _ready() -> void:
	print("BOOT STARTED")
	print("DisplayServer name: ", DisplayServer.get_name())

	if DisplayServer.get_name() == "headless":
		_start_server_boot()
	else:
		_start_client_boot()

func _start_server_boot() -> void:
	print("BOOT | RUNNING AS HEADLESS SERVER")

	var hosted_ok := NetworkManager.host_game(server_port)
	if not hosted_ok:
		print("BOOT | SERVER FAILED TO START")
		return

	call_deferred("_load_server_scene")

func _start_client_boot() -> void:
	print("BOOT | RUNNING AS CLIENT")
	NetworkManager.close_connection()
	call_deferred("_load_client_scene")

func _load_server_scene() -> void:
	print("BOOT | LOADING SERVER SCENE: ", server_scene_path)
	var err := get_tree().change_scene_to_file(server_scene_path)
	if err != OK:
		print("BOOT | FAILED TO LOAD SERVER SCENE: ", err)

func _load_client_scene() -> void:
	print("BOOT | LOADING CLIENT SCENE: ", client_scene_path)
	var err := get_tree().change_scene_to_file(client_scene_path)
	if err != OK:
		print("BOOT | FAILED TO LOAD CLIENT SCENE: ", err)
