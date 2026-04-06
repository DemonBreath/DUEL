extends Control

@export var arena_scene_path: String = "res://arena.tscn"
@export var default_server_ip: String = "8.229.209.249"
@export var default_server_port: int = 8910
@export var connect_timeout_seconds: float = 6.0

@onready var host_button: Button = $Panel/HostButton
@onready var join_button: Button = $Panel/JoinButton
@onready var ip_input: LineEdit = $Panel/IPInput
@onready var status_label: Label = $Panel/StatusLabel

var connection_in_progress: bool = false
var connect_timeout_timer: float = 0.0

func _ready() -> void:
	if host_button != null:
		host_button.visible = true
		host_button.disabled = false
		if not host_button.pressed.is_connected(_on_host_pressed):
			host_button.pressed.connect(_on_host_pressed)

	if join_button != null:
		join_button.visible = true
		join_button.disabled = false
		if not join_button.pressed.is_connected(_on_join_pressed):
			join_button.pressed.connect(_on_join_pressed)

	if ip_input != null:
		ip_input.visible = true
		ip_input.editable = true
		ip_input.text = default_server_ip
		ip_input.placeholder_text = "SERVER IP"

	if status_label != null:
		status_label.text = "READY"

	if not NetworkManager.connected_to_server.is_connected(_on_connected_to_server):
		NetworkManager.connected_to_server.connect(_on_connected_to_server)

	if not NetworkManager.connection_failed.is_connected(_on_connection_failed):
		NetworkManager.connection_failed.connect(_on_connection_failed)

	if not NetworkManager.disconnected_from_server.is_connected(_on_server_disconnected):
		NetworkManager.disconnected_from_server.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if not connection_in_progress:
		return

	connect_timeout_timer -= delta
	if connect_timeout_timer <= 0.0:
		_set_status("CONNECTION TIMED OUT")
		_set_connecting_state(false)
		NetworkManager.close_connection()

func _on_host_pressed() -> void:
	if connection_in_progress:
		return

	_set_status("HOSTING...")
	var ok := NetworkManager.host_game(default_server_port)
	if not ok:
		_set_status("FAILED TO HOST")
		return

	var err := get_tree().change_scene_to_file(arena_scene_path)
	if err != OK:
		_set_status("FAILED TO LOAD ARENA")
		push_error("MainMenu | Failed to load arena: %s" % arena_scene_path)

func _on_join_pressed() -> void:
	if connection_in_progress:
		return

	var ip := default_server_ip
	if ip_input != null and ip_input.text.strip_edges() != "":
		ip = ip_input.text.strip_edges()

	_set_status("CONNECTING...")
	_set_connecting_state(true)

	var ok := NetworkManager.join_game(ip, default_server_port)
	if not ok:
		_set_status("FAILED TO START CLIENT")
		_set_connecting_state(false)

func _on_connected_to_server() -> void:
	_set_status("CONNECTED")
	_set_connecting_state(false)

	var err := get_tree().change_scene_to_file(arena_scene_path)
	if err != OK:
		_set_status("FAILED TO LOAD ARENA")
		push_error("MainMenu | Failed to load arena: %s" % arena_scene_path)

func _on_connection_failed() -> void:
	_set_status("CONNECTION FAILED")
	_set_connecting_state(false)

func _on_server_disconnected() -> void:
	_set_status("SERVER DISCONNECTED")
	_set_connecting_state(false)

func _set_connecting_state(is_connecting: bool) -> void:
	connection_in_progress = is_connecting
	connect_timeout_timer = connect_timeout_seconds if is_connecting else 0.0

	if host_button != null:
		host_button.disabled = is_connecting

	if join_button != null:
		join_button.disabled = is_connecting

	if ip_input != null:
		ip_input.editable = not is_connecting

func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	print("MAIN MENU | ", text)
