extends Node3D

signal match_state_changed(new_state)
signal round_result(winner_id, loser_id)

const PLAYER_SCENE: PackedScene = preload("res://player.tscn")

const VALID_CHARACTER_IDS := [
	"turtle",
	"lava",
	"ice",
	"angel",
	"jackal",
	"nature",
	"shadow",
	"tech",
	"void"
]

enum MatchState {
	WAITING,
	COUNTDOWN,
	LIVE,
	ROUND_OVER
}

@export var round_reset_delay: float = 3.0
@export var countdown_seconds: int = 3

@export var hat_loadout_service_path: NodePath
@export var hat_match_controller_path: NodePath
@export var match_intro_controller_path: NodePath

@onready var players_root: Node3D = $Players
@onready var spawn_1: Marker3D = $SpawnPoints/Spawn1
@onready var spawn_2: Marker3D = $SpawnPoints/Spawn2

var hat_loadout_service: Node = null
var hat_match_controller: Node = null
var match_intro_controller: Node = null

var player_name_by_peer: Dictionary = {}
var spawned_players: Dictionary = {}
var connected_peer_order: Array[int] = []

var match_state: int = MatchState.WAITING
var round_number: int = 1
var scores: Dictionary = {}
var selected_character_by_peer: Dictionary = {}
var loadout_by_peer: Dictionary = {}

var round_reset_timer: float = 0.0
var countdown_timer: float = 0.0
var countdown_value_sent: int = -1

var hat_inventory_by_peer: Dictionary = {}
var account_id_by_peer: Dictionary = {}

func _ready() -> void:
	add_to_group("arena")

	hat_loadout_service = get_node_or_null(hat_loadout_service_path)
	hat_match_controller = get_node_or_null(hat_match_controller_path)
	match_intro_controller = get_node_or_null(match_intro_controller_path)

	if not NetworkManager.player_left.is_connected(_on_player_left):
		NetworkManager.player_left.connect(_on_player_left)

	if NetworkManager.is_host():
		if not NetworkManager.player_joined.is_connected(_on_player_joined_host):
			NetworkManager.player_joined.connect(_on_player_joined_host)

	match_state = MatchState.WAITING
	print("ARENA | READY | HOST=", NetworkManager.is_host())
	_emit_match_state("WAITING")
	_push_ui_status_to_local("WAITING FOR PLAYERS")
	_push_ui_round_number_to_local(round_number)
	_push_ui_score_to_local(scores)

	if NetworkManager.is_host():
		var host_peer_id := multiplayer.get_unique_id()

		if not connected_peer_order.has(host_peer_id):
			connected_peer_order.append(host_peer_id)

		_register_default_peer_data(host_peer_id)
		account_id_by_peer[host_peer_id] = HatAccountManager.get_local_account_id()
		hat_inventory_by_peer[host_peer_id] = HatAccountManager.get_local_hat_inventory().duplicate(true)

		var host_spawn := _get_spawn_transform_for_peer(host_peer_id)
		_spawn_player_for_peer_local(host_peer_id, host_spawn)
	else:
		call_deferred("_send_temp_client_defaults")
		call_deferred("_send_local_hat_inventory_to_host")

func _process(delta: float) -> void:
	if not NetworkManager.is_host():
		return

	match match_state:
		MatchState.COUNTDOWN:
			_process_countdown(delta)
		MatchState.ROUND_OVER:
			_process_round_over(delta)

func _process_countdown(delta: float) -> void:
	countdown_timer -= delta

	var display_value := int(ceil(countdown_timer))
	if display_value < 0:
		display_value = 0

	if display_value != countdown_value_sent:
		countdown_value_sent = display_value
		print("ARENA | COUNTDOWN: ", display_value)
		rpc("show_countdown_remote", display_value)

	if countdown_timer <= 0.0:
		start_round()

func _process_round_over(delta: float) -> void:
	round_reset_timer -= delta
	if round_reset_timer <= 0.0:
		reset_round()

func _on_player_joined_host(peer_id: int) -> void:
	if not NetworkManager.is_host():
		return

	if connected_peer_order.has(peer_id):
		print("ARENA | JOIN IGNORED | already known peer ", peer_id)
		return

	connected_peer_order.append(peer_id)
	_register_default_peer_data(peer_id)

	print("ARENA | PEER JOINED: ", peer_id, " | order=", connected_peer_order)

	if connected_peer_order.size() > 2:
		print("ARENA | EXTRA PEER CONNECTED BUT NOT SPAWNED: ", peer_id)
		return

	var spawn_transform := _get_spawn_transform_for_peer(peer_id)
	_spawn_player_for_peer_local(peer_id, spawn_transform)
	rpc("spawn_player_remote", peer_id, spawn_transform)

	for existing_peer_id in spawned_players.keys():
		var existing_int := int(existing_peer_id)
		if existing_int == peer_id:
			continue
		rpc_id(peer_id, "spawn_player_remote", existing_int, _get_spawn_transform_for_peer(existing_int))

	print("ARENA | PLAYER JOINED HOST: ", peer_id)

	if spawned_players.size() >= 2:
		begin_countdown()

func begin_countdown() -> void:
	if not NetworkManager.is_host():
		return
	if spawned_players.size() < 2:
		return

	_prepare_all_player_hats_for_match()
	_sync_all_hat_inventories_to_clients()

	match_state = MatchState.COUNTDOWN
	countdown_timer = float(countdown_seconds)
	countdown_value_sent = -1

	print("ARENA | MATCH STATE -> COUNTDOWN | round ", round_number)
	_emit_match_state("COUNTDOWN")

	_set_all_players_match_active_local(false, false)

	_push_ui_round_number_to_local(round_number)
	_push_ui_status_to_local("ROUND %d | GET READY" % round_number)

	rpc("begin_countdown_remote", round_number)

func start_round() -> void:
	if not NetworkManager.is_host():
		return

	match_state = MatchState.LIVE
	countdown_timer = 0.0
	countdown_value_sent = -1

	print("ARENA | MATCH STATE -> LIVE | round ", round_number)
	_emit_match_state("LIVE")

	_push_ui_status_to_local("ROUND %d | LIVE" % round_number)

	_set_all_players_match_active_local(false, true)

	if match_intro_controller != null:
		var host_peer_id := multiplayer.get_unique_id()
		var host_local_player: Node3D = get_spawned_player_for_peer(host_peer_id) as Node3D
		var host_enemy_player: Node3D = null

		for peer_id in spawned_players.keys():
			if int(peer_id) != host_peer_id:
				host_enemy_player = spawned_players[peer_id] as Node3D
				break

		if host_local_player != null and host_enemy_player != null:
			match_intro_controller.call("start_intro_for_players", host_local_player, host_enemy_player)

	rpc("start_match_intro_remote")
	rpc("set_round_live_remote", round_number)

func end_round(winner_peer_id: int, losing_peer_id: int) -> void:
	if not NetworkManager.is_host():
		return
	if match_state == MatchState.ROUND_OVER:
		return

	match_state = MatchState.ROUND_OVER
	round_reset_timer = round_reset_delay

	if winner_peer_id != -1:
		scores[winner_peer_id] = int(scores.get(winner_peer_id, 0)) + 1

	print("ARENA | MATCH STATE -> ROUND_OVER")
	print("ARENA | ROUND WINNER: ", winner_peer_id, " | LOSER: ", losing_peer_id)
	print("ARENA | SCORES: ", scores)

	var hat_result: Dictionary = _resolve_hat_wager_for_match(winner_peer_id, losing_peer_id)
	if not hat_result.is_empty():
		print("ARENA | HAT RESULT: ", hat_result)

	_sync_all_hat_inventories_to_clients()

	_emit_match_state("ROUND_OVER")
	emit_signal("round_result", winner_peer_id, losing_peer_id)

	_set_all_players_match_active_local(false, true)

	_push_ui_score_to_local(scores)
	_push_ui_status_to_local("ROUND OVER")

	rpc("show_round_result_remote", winner_peer_id, losing_peer_id, scores, round_number)

func reset_round() -> void:
	if not NetworkManager.is_host():
		return

	print("ARENA | RESETTING ROUND: ", round_number)

	for peer_id in spawned_players.keys():
		_respawn_player(int(peer_id), _get_spawn_transform_for_peer(int(peer_id)))

	round_number += 1

	if spawned_players.size() >= 2:
		begin_countdown()
	else:
		match_state = MatchState.WAITING
		_emit_match_state("WAITING")
		print("ARENA | MATCH STATE -> WAITING")
		_push_ui_status_to_local("WAITING FOR PLAYERS")

func _spawn_player_for_peer_local(peer_id: int, spawn_transform: Transform3D) -> void:
	if spawned_players.has(peer_id):
		print("ARENA | SPAWN BLOCKED | already exists ", peer_id)
		return

	var player_scene := _get_player_scene_for_peer(peer_id)
	var player := player_scene.instantiate()
	player.name = "Player_%s" % peer_id
	player.global_transform = spawn_transform
	player.set_multiplayer_authority(peer_id)

	if player.has_method("set_account_id"):
		var resolved_account_id := str(account_id_by_peer.get(peer_id, "peer_%s" % peer_id))
		player.call("set_account_id", resolved_account_id)

	if player.has_method("apply_loadout"):
		player.call("apply_loadout", get_loadout_for_peer(peer_id))

	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)

	players_root.add_child(player, true)
	spawned_players[peer_id] = player
	_apply_hat_inventory_to_spawned_player(peer_id)

	if not scores.has(peer_id):
		scores[peer_id] = 0

	if player.has_method("set_match_active"):
		player.call("set_match_active", false)

	print("ARENA | SPAWNED LOCAL PLAYER | ", player.name, " | authority = ", peer_id)

@rpc("authority", "call_remote")
func start_match_intro_remote() -> void:
	var local_peer_id := multiplayer.get_unique_id()
	var local_player: Node3D = get_spawned_player_for_peer(local_peer_id) as Node3D

	var enemy_player: Node3D = null
	for peer_id in spawned_players.keys():
		if int(peer_id) != local_peer_id:
			enemy_player = spawned_players[peer_id] as Node3D
			break

	if match_intro_controller != null and local_player != null and enemy_player != null:
		match_intro_controller.call("start_intro_for_players", local_player, enemy_player)

@rpc("authority", "call_remote")
func spawn_player_remote(peer_id: int, spawn_transform: Transform3D) -> void:
	if spawned_players.has(peer_id):
		print("ARENA | REMOTE SPAWN BLOCKED | already exists ", peer_id)
		return

	var player_scene := _get_player_scene_for_peer(peer_id)
	var player := player_scene.instantiate()
	player.name = "Player_%s" % peer_id
	player.global_transform = spawn_transform
	player.set_multiplayer_authority(peer_id)

	if player.has_method("set_account_id"):
		var resolved_account_id := str(account_id_by_peer.get(peer_id, "peer_%s" % peer_id))
		player.call("set_account_id", resolved_account_id)

	if player.has_method("apply_loadout"):
		player.call("apply_loadout", get_loadout_for_peer(peer_id))

	if player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)

	players_root.add_child(player, true)
	spawned_players[peer_id] = player
	_apply_hat_inventory_to_spawned_player(peer_id)

	if player.has_method("set_match_active"):
		player.call("set_match_active", false)

	print("ARENA | SPAWNED REMOTE PLAYER | ", player.name, " | authority = ", peer_id)

@rpc("any_peer")
func request_set_hat_inventory(peer_id: int, account_id: String, hat_inventory: Dictionary) -> void:
	if not NetworkManager.is_host():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		print("ARENA | HAT INVENTORY REJECTED | sender mismatch | sender=", sender_id, " peer_id=", peer_id)
		return

	account_id_by_peer[peer_id] = account_id
	hat_inventory_by_peer[peer_id] = hat_inventory.duplicate(true)

	print("ARENA | HAT INVENTORY APPROVED | peer ", peer_id, " | account_id=", account_id, " | ", hat_inventory)

	_apply_hat_inventory_to_spawned_player(peer_id)
	rpc("sync_hat_inventory_remote", peer_id, hat_inventory)

func _respawn_player(peer_id: int, spawn_transform: Transform3D) -> void:
	if not spawned_players.has(peer_id):
		return

	var player: Node = spawned_players[peer_id]
	if not is_instance_valid(player):
		return

	if player.has_method("reset_for_new_round"):
		player.call("reset_for_new_round", spawn_transform)

	if player.has_method("apply_loadout"):
		player.call("apply_loadout", get_loadout_for_peer(peer_id))

	if player.has_method("apply_hat_inventory_data") and hat_inventory_by_peer.has(peer_id):
		player.call("apply_hat_inventory_data", hat_inventory_by_peer[peer_id].duplicate(true))

	rpc("reset_player_remote", peer_id, spawn_transform)

@rpc("authority", "call_remote")
func sync_player_names_remote(name_map: Dictionary) -> void:
	player_name_by_peer = name_map.duplicate(true)
	print("ARENA | NAME SYNC: ", player_name_by_peer)

@rpc("any_peer")
func request_set_player_name(peer_id: int, player_name_value: String) -> void:
	if not NetworkManager.is_host():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		return

	player_name_by_peer[peer_id] = player_name_value
	print("ARENA | NAME SET | ", peer_id, " -> ", player_name_value)

	rpc("sync_player_names_remote", player_name_by_peer)

@rpc("authority", "call_remote")
func reset_player_remote(peer_id: int, spawn_transform: Transform3D) -> void:
	if not spawned_players.has(peer_id):
		return

	var player: Node = spawned_players[peer_id]
	if not is_instance_valid(player):
		return

	if player.has_method("reset_for_new_round"):
		player.call("reset_for_new_round", spawn_transform)

	if player.has_method("apply_loadout"):
		player.call("apply_loadout", get_loadout_for_peer(peer_id))

	if player.has_method("apply_hat_inventory_data") and hat_inventory_by_peer.has(peer_id):
		player.call("apply_hat_inventory_data", hat_inventory_by_peer[peer_id].duplicate(true))

	print("ARENA | REMOTE RESET PLAYER | ", player.name)

func _on_player_died(dead_account_id: String) -> void:
	if not NetworkManager.is_host():
		return
	if match_state != MatchState.LIVE:
		return

	var dead_peer_id := _peer_id_from_account_id(dead_account_id)
	if dead_peer_id == -1:
		print("ARENA | ROUND END FAILED | unknown dead account id: ", dead_account_id)
		return

	var winner_peer_id := _find_other_peer(dead_peer_id)
	end_round(winner_peer_id, dead_peer_id)

@rpc("any_peer")
func request_set_selected_character(peer_id: int, character_id: String) -> void:
	if not NetworkManager.is_host():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		print("ARENA | CHARACTER REJECTED | sender mismatch | sender=", sender_id, " peer_id=", peer_id)
		return

	var approved_character_id := character_id
	if not VALID_CHARACTER_IDS.has(approved_character_id):
		approved_character_id = "turtle"

	selected_character_by_peer[peer_id] = approved_character_id
	print("ARENA | CHARACTER APPROVED | peer ", peer_id, " -> ", approved_character_id)

	rpc("sync_selected_character_remote", selected_character_by_peer)

@rpc("any_peer")
func request_set_loadout(peer_id: int, loadout_data: Dictionary) -> void:
	if not NetworkManager.is_host():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		print("ARENA | LOADOUT REJECTED | sender mismatch | sender=", sender_id, " peer_id=", peer_id)
		return

	loadout_by_peer[peer_id] = sanitize_loadout(loadout_data)
	print("ARENA | LOADOUT APPROVED | peer ", peer_id, " -> ", loadout_by_peer[peer_id])

	rpc("sync_loadout_remote", loadout_by_peer)

@rpc("authority", "call_remote")
func sync_selected_character_remote(synced_character_map: Dictionary) -> void:
	selected_character_by_peer = synced_character_map.duplicate(true)
	print("ARENA | CHARACTER SYNC: ", selected_character_by_peer)

@rpc("authority", "call_remote")
func sync_loadout_remote(synced_loadout_map: Dictionary) -> void:
	loadout_by_peer = synced_loadout_map.duplicate(true)
	print("ARENA | LOADOUT SYNC: ", loadout_by_peer)

@rpc("authority", "call_remote")
func begin_countdown_remote(synced_round_number: int) -> void:
	round_number = synced_round_number
	print("ARENA | ROUND ", round_number, " | COUNTDOWN START")

	_set_all_players_match_active_local(false, false)

	_push_ui_round_number_to_local(round_number)
	_push_ui_status_to_local("ROUND %d | GET READY" % round_number)
	_push_ui_show_countdown_overlay()

@rpc("authority", "call_remote")
func show_countdown_remote(value: int) -> void:
	print("ARENA | COUNTDOWN: ", value)
	_push_ui_countdown_to_local(value)

@rpc("authority", "call_remote")
func set_round_live_remote(synced_round_number: int) -> void:
	round_number = synced_round_number
	print("ARENA | ROUND ", round_number, " | LIVE")

	_set_all_players_match_active_local(false, true)

	_push_ui_round_number_to_local(round_number)
	_push_ui_status_to_local("ROUND %d | LIVE" % round_number)
	_push_ui_countdown_to_local(-1)
	_push_ui_hide_countdown_overlay()

@rpc("authority", "call_remote")
func show_round_result_remote(winner_peer_id: int, losing_peer_id: int, synced_scores: Dictionary, synced_round_number: int) -> void:
	scores = synced_scores.duplicate(true)
	round_number = synced_round_number

	_set_all_players_match_active_local(false, true)

	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id == winner_peer_id:
		print("ARENA | ROUND RESULT: YOU WIN")
		_push_ui_result_to_local("YOU WIN")
		_push_ui_show_victory()
	elif local_peer_id == losing_peer_id:
		print("ARENA | ROUND RESULT: YOU LOSE")
		_push_ui_result_to_local("YOU LOSE")
		_push_ui_show_defeat()
	else:
		print("ARENA | ROUND RESULT: SPECTATOR/UNKNOWN")
		_push_ui_result_to_local("ROUND OVER")

	print("ARENA | SYNCED SCORES: ", scores)
	_push_ui_score_to_local(scores)
	_push_ui_status_to_local("ROUND OVER")

@rpc("authority", "call_remote")
func sync_hat_inventory_remote(peer_id: int, hat_data: Dictionary) -> void:
	hat_inventory_by_peer[peer_id] = hat_data.duplicate(true)

	if spawned_players.has(peer_id):
		var player: Node = spawned_players[peer_id]
		if is_instance_valid(player) and player.has_method("apply_hat_inventory_data"):
			player.call("apply_hat_inventory_data", hat_data.duplicate(true))
			print("ARENA | HAT SYNC APPLIED | peer ", peer_id, " | ", hat_data)
	else:
		print("ARENA | HAT SYNC STORED ONLY | missing player for peer ", peer_id)

	var local_peer_id := multiplayer.get_unique_id()
	if peer_id == local_peer_id:
		HatAccountManager.set_local_hat_inventory(hat_data.duplicate(true))
		print("ARENA | SAVED LOCAL HAT INVENTORY FROM HOST SYNC")

func _set_all_players_match_active_local(is_active: bool, duel_over_state: bool = false) -> void:
	for peer_id in spawned_players.keys():
		var player: Node = spawned_players[peer_id]
		if not is_instance_valid(player):
			continue

		if player.has_method("set_duel_over"):
			player.call("set_duel_over", duel_over_state)

		if player.has_method("set_match_active"):
			player.call("set_match_active", is_active)

		print("ARENA | LOCAL PLAYER STATE | ", player.name, " | match_active=", is_active, " | duel_over=", duel_over_state)

func _prepare_all_player_hats_for_match() -> void:
	for peer_id in spawned_players.keys():
		_prepare_player_hat_for_match(int(peer_id))

func _prepare_player_hat_for_match(peer_id: int) -> void:
	if hat_loadout_service == null:
		print("ARENA | HAT PREP SKIPPED | HatLoadoutService missing")
		return

	if not spawned_players.has(peer_id):
		print("ARENA | HAT PREP SKIPPED | missing player for peer ", peer_id)
		return

	var player: Node = spawned_players[peer_id]
	if not is_instance_valid(player):
		print("ARENA | HAT PREP SKIPPED | invalid player for peer ", peer_id)
		return

	if not player.has_method("get_player_inventory"):
		print("ARENA | HAT PREP SKIPPED | player missing get_player_inventory()")
		return

	var inventory: Node = player.call("get_player_inventory")
	if inventory == null:
		print("ARENA | HAT PREP SKIPPED | inventory missing for peer ", peer_id)
		return

	var prep_result: Dictionary = hat_loadout_service.call("prepare_inventory_for_match", inventory)
	print("ARENA | HAT PREP | peer ", peer_id, " | ", prep_result)

func _resolve_hat_wager_for_match(winner_peer_id: int, losing_peer_id: int) -> Dictionary:
	if hat_match_controller == null:
		print("ARENA | HAT RESOLVE SKIPPED | HatMatchController missing")
		return {}

	if winner_peer_id == -1 or losing_peer_id == -1:
		print("ARENA | HAT RESOLVE SKIPPED | invalid peer ids")
		return {}

	if not spawned_players.has(winner_peer_id) or not spawned_players.has(losing_peer_id):
		print("ARENA | HAT RESOLVE SKIPPED | missing winner/loser player nodes")
		return {}

	var winner_player: Node = spawned_players[winner_peer_id]
	var loser_player: Node = spawned_players[losing_peer_id]

	if not is_instance_valid(winner_player) or not is_instance_valid(loser_player):
		print("ARENA | HAT RESOLVE SKIPPED | invalid winner/loser player nodes")
		return {}

	var result: Dictionary = hat_match_controller.call("resolve_match_result", winner_player, loser_player)

	if winner_player.has_method("get_hat_inventory_data"):
		hat_inventory_by_peer[winner_peer_id] = winner_player.call("get_hat_inventory_data").duplicate(true)

	if loser_player.has_method("get_hat_inventory_data"):
		hat_inventory_by_peer[losing_peer_id] = loser_player.call("get_hat_inventory_data").duplicate(true)

	print("ARENA | HAT MATCH RESULT: ", result)

	var win_text: String = str(hat_match_controller.call("get_win_result_text", result))
	var loss_text: String = str(hat_match_controller.call("get_loss_result_text", result))

	print("ARENA | HAT WIN TEXT:\n", win_text)
	print("ARENA | HAT LOSS TEXT:\n", loss_text)

	return result

func _sync_all_hat_inventories_to_clients() -> void:
	if not NetworkManager.is_host():
		return

	for peer_id in spawned_players.keys():
		var int_peer_id := int(peer_id)
		var hat_data: Dictionary = _get_hat_data_for_peer(int_peer_id)
		if hat_data.is_empty():
			continue

		hat_inventory_by_peer[int_peer_id] = hat_data.duplicate(true)

		sync_hat_inventory_remote(int_peer_id, hat_data.duplicate(true))
		rpc("sync_hat_inventory_remote", int_peer_id, hat_data.duplicate(true))

func _get_hat_data_for_peer(peer_id: int) -> Dictionary:
	if spawned_players.has(peer_id):
		var player: Node = spawned_players[peer_id]
		if is_instance_valid(player) and player.has_method("get_hat_inventory_data"):
			return player.call("get_hat_inventory_data").duplicate(true)

	if hat_inventory_by_peer.has(peer_id):
		return hat_inventory_by_peer[peer_id].duplicate(true)

	return {}

func _get_spawn_transform_for_peer(peer_id: int) -> Transform3D:
	var index := connected_peer_order.find(peer_id)
	if index == 0:
		return spawn_1.global_transform
	return spawn_2.global_transform

func _register_default_peer_data(peer_id: int) -> void:
	if not selected_character_by_peer.has(peer_id):
		selected_character_by_peer[peer_id] = "turtle"

	if not loadout_by_peer.has(peer_id):
		loadout_by_peer[peer_id] = get_default_loadout()

func _get_player_scene_for_peer(_peer_id: int) -> PackedScene:
	return PLAYER_SCENE

func get_default_loadout() -> Dictionary:
	return {
		"stat_modifiers": {
			"move_speed": 1.0,
			"jump_force": 1.0,
			"aim_move_multiplier": 0.0,
			"shot_cooldown": 1.0,
			"max_health": 100
		}
	}

func get_loadout_for_peer(peer_id: int) -> Dictionary:
	if not loadout_by_peer.has(peer_id):
		loadout_by_peer[peer_id] = get_default_loadout()

	return loadout_by_peer[peer_id].duplicate(true)

func sanitize_loadout(loadout_data: Dictionary) -> Dictionary:
	var clean := get_default_loadout()
	var mods_in: Dictionary = loadout_data.get("stat_modifiers", {})
	var clean_mods: Dictionary = clean["stat_modifiers"]

	clean_mods["move_speed"] = clamp(float(mods_in.get("move_speed", 1.0)), 0.5, 2.0)
	clean_mods["jump_force"] = clamp(float(mods_in.get("jump_force", 1.0)), 0.5, 2.0)
	clean_mods["aim_move_multiplier"] = clamp(float(mods_in.get("aim_move_multiplier", 0.0)), 0.0, 1.0)
	clean_mods["shot_cooldown"] = clamp(float(mods_in.get("shot_cooldown", 1.0)), 0.25, 2.0)
	clean_mods["max_health"] = clamp(int(mods_in.get("max_health", 100)), 50, 200)

	clean["stat_modifiers"] = clean_mods
	return clean

func _send_temp_client_defaults() -> void:
	var ui := get_node_or_null("/root/TestArena/GameUI")
	if ui == null:
		print("ARENA | TEMP DEFAULTS | GameUI not found")
		return

	if ui.has_method("send_selected_character"):
		ui.call("send_selected_character", "turtle")

	if ui.has_method("send_loadout_data"):
		ui.call("send_loadout_data", {
			"stat_modifiers": {
				"move_speed": 1.0,
				"jump_force": 1.0,
				"aim_move_multiplier": 0.0,
				"shot_cooldown": 1.0,
				"max_health": 100
			}
		})

	print("ARENA | TEMP DEFAULTS | sent character + loadout")

func _on_player_left(peer_id: int) -> void:
	if spawned_players.has(peer_id):
		var player: Node = spawned_players[peer_id]
		if is_instance_valid(player):
			player.queue_free()
		spawned_players.erase(peer_id)

	connected_peer_order.erase(peer_id)

	if selected_character_by_peer.has(peer_id):
		selected_character_by_peer.erase(peer_id)

	if loadout_by_peer.has(peer_id):
		loadout_by_peer.erase(peer_id)

	if hat_inventory_by_peer.has(peer_id):
		hat_inventory_by_peer.erase(peer_id)

	if account_id_by_peer.has(peer_id):
		account_id_by_peer.erase(peer_id)

	print("ARENA | REMOVED PLAYER | ", peer_id)

	if match_state != MatchState.WAITING:
		match_state = MatchState.WAITING
		_emit_match_state("WAITING")
		print("ARENA | MATCH STATE -> WAITING (disconnect)")
		_push_ui_status_to_local("WAITING FOR PLAYERS")

func _peer_id_from_account_id(account_id: String) -> int:
	for peer_id in account_id_by_peer.keys():
		if str(account_id_by_peer[peer_id]) == account_id:
			return int(peer_id)

	if account_id.begins_with("peer_"):
		return int(account_id.trim_prefix("peer_"))

	return -1

func _find_other_peer(dead_peer_id: int) -> int:
	for peer_id in spawned_players.keys():
		if int(peer_id) != dead_peer_id:
			return int(peer_id)
	return -1

func _emit_match_state(state_name: String) -> void:
	emit_signal("match_state_changed", state_name)

func _get_game_ui() -> Node:
	return get_node_or_null("GameUI")

func _push_ui_status_to_local(text: String) -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("set_match_status"):
		ui.call("set_match_status", text)

func _push_ui_countdown_to_local(value: int) -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("set_countdown_value"):
		ui.call("set_countdown_value", value)

func _push_ui_result_to_local(text: String) -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("show_round_result_text"):
		ui.call("show_round_result_text", text)

func _push_ui_score_to_local(synced_scores: Dictionary) -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("set_score_data"):
		ui.call("set_score_data", synced_scores)

func _push_ui_round_number_to_local(value: int) -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("set_round_number"):
		ui.call("set_round_number", value)

func _push_ui_show_victory() -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("show_victory"):
		ui.call("show_victory")

func _push_ui_show_defeat() -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("show_defeat"):
		ui.call("show_defeat")

func _push_ui_show_countdown_overlay() -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("show_countdown_overlay"):
		ui.call("show_countdown_overlay")

func _push_ui_hide_countdown_overlay() -> void:
	var ui := _get_game_ui()
	if ui != null and ui.has_method("hide_countdown_overlay"):
		ui.call("hide_countdown_overlay")

func _send_local_hat_inventory_to_host() -> void:
	if NetworkManager.is_host():
		return

	var local_peer_id := multiplayer.get_unique_id()
	var local_account_id := HatAccountManager.get_local_account_id()
	var local_hat_inventory := HatAccountManager.get_local_hat_inventory().duplicate(true)

	print("ARENA | SENDING LOCAL HAT INVENTORY | peer ", local_peer_id, " | account_id=", local_account_id, " | ", local_hat_inventory)

	rpc_id(1, "request_set_hat_inventory", local_peer_id, local_account_id, local_hat_inventory)

func _apply_hat_inventory_to_spawned_player(peer_id: int) -> void:
	if not spawned_players.has(peer_id):
		return

	if not hat_inventory_by_peer.has(peer_id):
		return

	var player: Node = spawned_players[peer_id]
	if not is_instance_valid(player):
		return

	if player.has_method("apply_hat_inventory_data"):
		player.call("apply_hat_inventory_data", hat_inventory_by_peer[peer_id].duplicate(true))

	if player.has_method("set_account_id"):
		var resolved_account_id := str(account_id_by_peer.get(peer_id, "peer_%s" % peer_id))
		player.call("set_account_id", resolved_account_id)

	print("ARENA | APPLIED STORED HAT INVENTORY TO PLAYER | peer ", peer_id)
	
func get_spawned_player_for_peer(peer_id: int) -> Node:
	if spawned_players.has(peer_id):
		return spawned_players[peer_id]
	return null
