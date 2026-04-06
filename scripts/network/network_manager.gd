extends Node

signal connected_to_server
signal connection_failed
signal disconnected_from_server
signal player_joined(peer_id)
signal player_left(peer_id)

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 2

var peer: ENetMultiplayerPeer = null
var current_port: int = DEFAULT_PORT

func _ready() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)

	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT) -> bool:
	close_connection()

	current_port = port
	peer = ENetMultiplayerPeer.new()

	var result := peer.create_server(current_port, MAX_PLAYERS)
	if result != OK:
		push_error("NetworkManager | Failed to host game: %s" % result)
		peer = null
		return false

	multiplayer.multiplayer_peer = peer
	print("NETWORK | Hosting on port %d" % current_port)
	return true

func join_game(ip_address: String, port: int = DEFAULT_PORT) -> bool:
	close_connection()

	current_port = port
	peer = ENetMultiplayerPeer.new()

	var result := peer.create_client(ip_address.strip_edges(), current_port)
	if result != OK:
		push_error("NetworkManager | Failed to join game: %s" % result)
		peer = null
		return false

	multiplayer.multiplayer_peer = peer
	print("NETWORK | Joining %s:%d" % [ip_address, current_port])
	return true

func close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()

	multiplayer.multiplayer_peer = null
	peer = null

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func has_active_connection() -> bool:
	return multiplayer.multiplayer_peer != null

func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()

func _on_peer_connected(peer_id: int) -> void:
	print("NETWORK | Peer connected: ", peer_id)
	player_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	print("NETWORK | Peer disconnected: ", peer_id)
	player_left.emit(peer_id)

func _on_connected_to_server() -> void:
	print("NETWORK | Connected to server")
	connected_to_server.emit()

func _on_connection_failed() -> void:
	print("NETWORK | Connection failed")
	connection_failed.emit()
	close_connection()

func _on_server_disconnected() -> void:
	print("NETWORK | Server disconnected")
	disconnected_from_server.emit()
	close_connection()
