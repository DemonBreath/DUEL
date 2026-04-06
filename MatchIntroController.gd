extends Node

@export var reveal_scene: PackedScene

var reveal_instance: Node3D = null

var local_ready: bool = false
var enemy_ready: bool = false
var intro_active: bool = false

var local_reveal_info: Dictionary = {}
var remote_reveal_info: Dictionary = {}

var server_player_data: Dictionary = {}

var fallback_enemy_info := {
	"player_name": "GOLIATH_X",
	"bullets": 9,
	"mobs": [
		{"name": "tank"},
		{"name": "leech"},
		{"name": "scout"}
	],
	"wins": 7,
	"deaths": 2,
	"note": "HEAVY"
}

func _ready() -> void:
	add_to_group("intro_controller")

func begin_network_intro(local_info: Dictionary) -> void:
	local_reveal_info = local_info
	local_ready = false
	enemy_ready = false
	intro_active = false
	remote_reveal_info = {}

	if multiplayer.get_peers().is_empty():
		print("No remote peers found - using fallback enemy info")
		_spawn_intro(fallback_enemy_info)
		_refresh_arena_hud()
		return

	if multiplayer.is_server():
		_server_receive_reveal_info(multiplayer.get_unique_id(), local_info)
	else:
		rpc_id(1, "_server_receive_reveal_info", multiplayer.get_unique_id(), local_info)

func set_local_ready() -> void:
	if not intro_active:
		print("set_local_ready ignored - intro not active")
		return

	if multiplayer.get_peers().is_empty():
		local_ready = true
		_update_ui_ready()
		_refresh_arena_hud()

		await get_tree().create_timer(0.8).timeout

		enemy_ready = true
		_update_ui_ready()
		_refresh_arena_hud()

		await get_tree().create_timer(0.3).timeout

		_start_match()
		return

	if multiplayer.is_server():
		_server_set_ready(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_server_set_ready", multiplayer.get_unique_id())

@rpc("any_peer")
func _server_receive_reveal_info(peer_id: int, info: Dictionary) -> void:
	server_player_data[peer_id] = info
	print("Server received reveal info from peer: ", peer_id)

	if server_player_data.size() < 2:
		return

	var peer_ids := server_player_data.keys()
	if peer_ids.size() != 2:
		return

	var peer_a: int = int(peer_ids[0])
	var peer_b: int = int(peer_ids[1])

	var info_a: Dictionary = server_player_data[peer_a]
	var info_b: Dictionary = server_player_data[peer_b]

	if peer_a == multiplayer.get_unique_id():
		_client_receive_enemy_info(info_b)
	else:
		rpc_id(peer_a, "_client_receive_enemy_info", info_b)

	if peer_b == multiplayer.get_unique_id():
		_client_receive_enemy_info(info_a)
	else:
		rpc_id(peer_b, "_client_receive_enemy_info", info_a)

@rpc("any_peer")
func _client_receive_enemy_info(enemy_info: Dictionary) -> void:
	print("Received enemy reveal info")
	remote_reveal_info = enemy_info
	_spawn_intro(enemy_info)
	_refresh_arena_hud()

func _spawn_intro(enemy_info: Dictionary) -> void:
	if reveal_scene == null:
		push_warning("Missing reveal_scene")
		return

	if reveal_instance != null and is_instance_valid(reveal_instance):
		reveal_instance.queue_free()
		reveal_instance = null

	reveal_instance = reveal_scene.instantiate() as Node3D
	if reveal_instance == null:
		push_warning("Reveal scene is not Node3D")
		return

	add_child(reveal_instance)
	reveal_instance.position = Vector3(0.0, 1.5, -3.0)

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var visuals = player.get_node_or_null("Visuals")
		if visuals != null:
			visuals.visible = false

	var preview_camera := reveal_instance.get_node_or_null("PreviewCamera") as Camera3D
	if preview_camera != null:
		preview_camera.current = true
	else:
		push_warning("Reveal scene is missing PreviewCamera")

	if reveal_instance.has_method("set_enemy_reveal_from_info"):
		reveal_instance.call("set_enemy_reveal_from_info", enemy_info)

	local_ready = false
	enemy_ready = false
	intro_active = true
	_update_ui_ready()
	_refresh_arena_hud()

@rpc("any_peer")
func _server_set_ready(peer_id: int) -> void:
	var peer_ids := server_player_data.keys()
	if peer_ids.size() < 2:
		return

	var local_peer: int = multiplayer.get_unique_id()
	var other_peer: int = -1

	for id in peer_ids:
		if int(id) != local_peer:
			other_peer = int(id)
			break

	if peer_id == local_peer:
		local_ready = true
	elif peer_id == other_peer:
		enemy_ready = true

	_update_ui_ready_state_for_all()

	if local_ready and enemy_ready:
		_start_match()

func _update_ui_ready_state_for_all() -> void:
	rpc("_client_update_ready", local_ready, enemy_ready)
	_client_update_ready(local_ready, enemy_ready)

@rpc("any_peer")
func _client_update_ready(local_r: bool, enemy_r: bool) -> void:
	local_ready = local_r
	enemy_ready = enemy_r
	_update_ui_ready()
	_refresh_arena_hud()

func _update_ui_ready() -> void:
	if reveal_instance != null and reveal_instance.has_method("set_ready_state"):
		reveal_instance.call("set_ready_state", local_ready, enemy_ready)

func _refresh_arena_hud() -> void:
	var arena = get_parent()
	if arena != null and arena.has_method("update_intro_hud"):
		arena.update_intro_hud()

func _start_match() -> void:
	rpc("_client_start_match")
	_client_start_match()

@rpc("any_peer")
func _client_start_match() -> void:
	print("BOTH READY - STARTING MATCH")

	intro_active = false

	if reveal_instance != null and is_instance_valid(reveal_instance):
		var preview_camera := reveal_instance.get_node_or_null("PreviewCamera") as Camera3D
		if preview_camera != null:
			preview_camera.current = false

		reveal_instance.queue_free()
		reveal_instance = null

	var arena = get_parent()
	if arena != null and arena.has_method("unlock_match"):
		arena.unlock_match()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var visuals = player.get_node_or_null("Visuals")
		if visuals != null:
			visuals.visible = true

		if player.has_node("CameraPivot/Camera3D"):
			var player_camera := player.get_node("CameraPivot/Camera3D") as Camera3D
			if player_camera != null:
				player_camera.current = true

func send_rotation(y: float, x: float) -> void:
	if not intro_active:
		return

	if multiplayer.get_peers().is_empty():
		if reveal_instance != null:
			var solo_pivot := reveal_instance.get_node_or_null("Pivot") as Node3D
			if solo_pivot != null:
				solo_pivot.rotation.y = y
				solo_pivot.rotation.x = x
		return

	if multiplayer.is_server():
		_server_set_rotation(y, x)
	else:
		rpc_id(1, "_server_set_rotation", y, x)

@rpc("any_peer")
func _server_set_rotation(y: float, x: float) -> void:
	rpc("_client_apply_rotation", y, x)
	_client_apply_rotation(y, x)

@rpc("any_peer")
func _client_apply_rotation(y: float, x: float) -> void:
	if reveal_instance != null:
		var pivot := reveal_instance.get_node_or_null("Pivot") as Node3D
		if pivot != null:
			pivot.rotation.y = y
			pivot.rotation.x = x
