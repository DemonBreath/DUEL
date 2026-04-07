extends Node

var local_player: Node = null
var enemy_player: Node = null
var arena: Node = null
var combat_complete: bool = false
var last_aim_log_time_msec: int = 0

func _ready() -> void:
	set_process(true)
	if is_enabled():
		print("MATCH TEST | enabled")

func is_enabled() -> bool:
	return LaunchOptions.has_flag("test-bot") or LaunchOptions.has_flag("smoke-combat")

func _process(_delta: float) -> void:
	if not is_enabled():
		return

	_refresh_references()

	if arena == null or local_player == null or enemy_player == null:
		return

	if combat_complete:
		return

	if not arena.has_method("get_match_state_name"):
		return

	var match_state := str(arena.call("get_match_state_name"))
	if match_state != "LIVE":
		return

	if local_player.has_method("is_test_combat_ready") and not bool(local_player.call("is_test_combat_ready")):
		return

	var target_position: Vector3 = enemy_player.global_position + Vector3(0.0, 1.2, 0.0)
	if local_player.has_method("test_aim_at_world_position"):
		local_player.call("test_aim_at_world_position", target_position)

	if local_player.has_method("test_request_fire"):
		local_player.call("test_request_fire")

	var now_msec := Time.get_ticks_msec()
	if now_msec - last_aim_log_time_msec >= 1000:
		last_aim_log_time_msec = now_msec
		print("MATCH TEST | driving combat | target=", enemy_player.name)

func mark_combat_complete() -> void:
	combat_complete = true
	print("MATCH TEST | combat complete")

func _refresh_references() -> void:
	arena = _find_arena()
	local_player = _find_local_player()
	enemy_player = _find_enemy_player(local_player)

func _find_arena() -> Node:
	var arenas := get_tree().get_nodes_in_group("arena")
	if arenas.is_empty():
		return null
	return arenas[0]

func _find_local_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if player.has_method("is_local_player") and bool(player.call("is_local_player")):
			return player
	return null

func _find_enemy_player(local_candidate: Node) -> Node:
	if local_candidate == null:
		return null

	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if player != local_candidate:
			return player
	return null
