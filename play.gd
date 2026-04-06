extends Button

@export var next_scene_path: String = "res://arena.tscn"
@export var server_ip: String = "8.229.209.249"
@export var server_port: int = 8910
@export var connect_timeout_seconds: float = 6.0

@onready var hover_glow: TextureRect = $"../HoverGlow"

var connection_in_progress: bool = false
var connect_timeout_timer: float = 0.0

func _ready() -> void:
	print("PLAY BUTTON READY")

	disabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	modulate.a = 0.0

	if hover_glow != null:
		hover_glow.visible = false
		hover_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	connection_in_progress = false
	connect_timeout_timer = 0.0

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

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
		print("PLAY BUTTON | CONNECTION TIMEOUT")
		_reset_connection_state()

func _on_pressed() -> void:
	if connection_in_progress:
		print("PLAY BUTTON | ALREADY TRYING TO CONNECT")
		return

	print("PLAY BUTTON | CONNECTING TO SERVER")
	disabled = true
	connection_in_progress = true
	connect_timeout_timer = connect_timeout_seconds

	var ok := NetworkManager.join_game(server_ip, server_port)
	if not ok:
		print("PLAY BUTTON | FAILED TO START CLIENT")
		_reset_connection_state()

func _on_connected_to_server() -> void:
	print("PLAY BUTTON | CONNECTED TO SERVER")
	connection_in_progress = false
	connect_timeout_timer = 0.0

	var err := get_tree().change_scene_to_file(next_scene_path)
	if err != OK:
		push_error("PlayButton | Failed to load next scene: %s" % next_scene_path)
		_reset_connection_state()

func _on_connection_failed() -> void:
	print("PLAY BUTTON | CONNECTION FAILED")
	_reset_connection_state()

func _on_server_disconnected() -> void:
	print("PLAY BUTTON | SERVER DISCONNECTED")
	_reset_connection_state()

func _reset_connection_state() -> void:
	connection_in_progress = false
	connect_timeout_timer = 0.0
	disabled = false
	NetworkManager.close_connection()

func _on_mouse_entered() -> void:
	print("PLAY HOVERED")
	if hover_glow != null:
		hover_glow.visible = true

func _on_mouse_exited() -> void:
	print("PLAY UNHOVERED")
	if hover_glow != null:
		hover_glow.visible = false
