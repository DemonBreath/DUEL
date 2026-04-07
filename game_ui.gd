extends CanvasLayer

@onready var hitmarker_root: Control = $Hitmarker
@onready var hitmarker_audio: AudioStreamPlayer = $Hitmarker/Audio
@onready var crosshair: TextureRect = $Crosshair

@onready var overlay_root: Control = $OverlayRoot
@onready var victory_overlay: TextureRect = $OverlayRoot/VictoryOverlay
@onready var defeat_overlay: TextureRect = $OverlayRoot/DefeatOverlay
@onready var countdown_overlay: TextureRect = $OverlayRoot/CountdownOverlay

@export var hitmarker_duration: float = 0.10

var hitmarker_timer: float = 0.0
var connected_player: Node = null
var player_name_sent_to_server: bool = false

var current_match_status: String = ""
var current_countdown_value: int = -1
var current_round_result: String = ""
var current_score_data: Dictionary = {}
var current_round_number: int = 1
var current_ready_state: Dictionary = {}
var current_intro_data: Dictionary = {}
var current_selected_character: String = "turtle"
var current_loadout_data: Dictionary = {}
var smoke_exit_scheduled: bool = false

func is_dedicated_server() -> bool:
	return DisplayServer.get_name() == "headless"

func _ready() -> void:
	add_to_group("game_ui")

	if crosshair != null:
		crosshair.visible = false

	if hitmarker_root != null:
		hitmarker_root.visible = false
		hitmarker_root.modulate = Color(1, 1, 1, 1)

	hide_all_overlays()

	if is_dedicated_server():
		return

	call_deferred("_connect_to_local_player")

func _process(delta: float) -> void:
	if is_dedicated_server():
		return

	if connected_player == null or not is_instance_valid(connected_player):
		_connect_to_local_player()

	if not player_name_sent_to_server:
		_try_send_player_name()

	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0 and hitmarker_root != null:
			hitmarker_root.visible = false

func _connect_to_local_player() -> void:
	connected_player = null

	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p.has_method("is_local_player") and p.call("is_local_player"):
			if str(p.name).begins_with("Player_"):
				connected_player = p
				break

	if connected_player != null:
		if connected_player.has_signal("shot_fired") and not connected_player.shot_fired.is_connected(_on_player_shot_fired):
			connected_player.shot_fired.connect(_on_player_shot_fired)

		if connected_player.has_signal("shot_hit") and not connected_player.shot_hit.is_connected(_on_player_shot_hit):
			connected_player.shot_hit.connect(_on_player_shot_hit)

		if connected_player.has_signal("shot_missed") and not connected_player.shot_missed.is_connected(_on_player_shot_missed):
			connected_player.shot_missed.connect(_on_player_shot_missed)

		if connected_player.has_signal("crosshair_visibility_requested") and not connected_player.crosshair_visibility_requested.is_connected(_on_crosshair_visibility_requested):
			connected_player.crosshair_visibility_requested.connect(_on_crosshair_visibility_requested)

		print("GAMEUI | connected to local spawned player: ", connected_player.name)

func _try_send_player_name() -> void:
	if is_dedicated_server():
		return

	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.is_server():
		return

	var arena := get_node_or_null("/root/TestArena/Arena")
	if arena == null:
		return

	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return

	arena.rpc_id(1, "request_set_player_name", local_peer_id, PlayerNameManager.get_player_name_value())
	player_name_sent_to_server = true

	print("GAMEUI | NAME SENT: ", PlayerNameManager.get_player_name_value())

func _on_crosshair_visibility_requested(should_show: bool) -> void:
	if crosshair != null:
		crosshair.visible = should_show

func _on_player_shot_fired(_shot_data: Dictionary) -> void:
	print("GAMEUI | shot_fired received")

func _on_player_shot_hit(_shot_data: Dictionary) -> void:
	print("GAMEUI | shot_hit received")
	show_hitmarker()

func _on_player_shot_missed(_shot_data: Dictionary) -> void:
	print("GAMEUI | shot_missed received")

func show_hitmarker() -> void:
	print("GAMEUI | show_hitmarker called")

	if hitmarker_root != null:
		hitmarker_root.visible = true
		hitmarker_root.modulate = Color(1, 1, 1, 1)

	var icon: CanvasItem = $Hitmarker/Icon
	if icon != null:
		icon.visible = true
		icon.modulate = Color(1, 1, 1, 1)
		if icon.has_method("set_scale"):
			icon.scale = Vector2.ONE

	hitmarker_timer = hitmarker_duration

	if hitmarker_audio != null:
		hitmarker_audio.play()

func hide_all_overlays() -> void:
	if victory_overlay != null:
		victory_overlay.visible = false
	if defeat_overlay != null:
		defeat_overlay.visible = false
	if countdown_overlay != null:
		countdown_overlay.visible = false

func show_victory() -> void:
	hide_all_overlays()
	if victory_overlay != null:
		victory_overlay.visible = true
	print("GAMEUI | VICTORY OVERLAY")

func show_defeat() -> void:
	hide_all_overlays()
	if defeat_overlay != null:
		defeat_overlay.visible = true
	print("GAMEUI | DEFEAT OVERLAY")

func show_countdown_overlay() -> void:
	hide_all_overlays()
	if countdown_overlay != null:
		countdown_overlay.visible = true
	print("GAMEUI | COUNTDOWN OVERLAY")

func hide_countdown_overlay() -> void:
	if countdown_overlay != null:
		countdown_overlay.visible = false
	print("GAMEUI | COUNTDOWN OVERLAY HIDDEN")

func set_match_status(text: String) -> void:
	current_match_status = text
	print("GAMEUI STATUS: ", text)

func set_countdown_value(value: int) -> void:
	current_countdown_value = value
	if value >= 0:
		print("GAMEUI COUNTDOWN: ", value)
		show_countdown_overlay()
	else:
		print("GAMEUI COUNTDOWN CLEARED")
		hide_countdown_overlay()

func show_round_result_text(text: String) -> void:
	current_round_result = text
	print("GAMEUI RESULT: ", text)

	if text == "YOU WIN":
		show_victory()
	elif text == "YOU LOSE":
		show_defeat()

	_validate_expected_local_result(text)

	if LaunchOptions.should_smoke_exit_on_scene("round_over"):
		_schedule_smoke_exit()

func set_score_data(synced_scores: Dictionary) -> void:
	current_score_data = synced_scores.duplicate(true)
	print("GAMEUI SCORES: ", current_score_data)

func set_round_number(value: int) -> void:
	current_round_number = value
	print("GAMEUI ROUND: ", value)

func set_ready_state(synced_ready: Dictionary) -> void:
	current_ready_state = synced_ready.duplicate(true)
	print("GAMEUI READY STATE: ", current_ready_state)

func show_intro_data(reveal_data: Dictionary) -> void:
	current_intro_data = reveal_data.duplicate(true)
	print("GAMEUI INTRO DATA: ", current_intro_data)

func send_ready_request() -> void:
	if is_dedicated_server():
		return

	if not multiplayer.has_multiplayer_peer():
		print("GAMEUI READY | no multiplayer peer")
		return

	var arena := get_node_or_null("/root/TestArena/Arena")
	if arena == null:
		print("GAMEUI READY | Arena not found")
		return

	var local_peer_id := multiplayer.get_unique_id()
	arena.rpc_id(1, "request_set_ready", local_peer_id, true)
	print("GAMEUI READY | request sent for peer ", local_peer_id)

func send_selected_character(character_id: String) -> void:
	current_selected_character = character_id

	if is_dedicated_server():
		return

	if not multiplayer.has_multiplayer_peer():
		print("GAMEUI CHARACTER | no multiplayer peer")
		return

	var arena := get_node_or_null("/root/TestArena/Arena")
	if arena == null:
		print("GAMEUI CHARACTER | Arena not found")
		return

	var local_peer_id := multiplayer.get_unique_id()
	arena.rpc_id(1, "request_set_selected_character", local_peer_id, character_id)
	print("GAMEUI CHARACTER | request sent | peer ", local_peer_id, " -> ", character_id)

func send_loadout_data(loadout_data: Dictionary) -> void:
	current_loadout_data = loadout_data.duplicate(true)

	if is_dedicated_server():
		return

	if not multiplayer.has_multiplayer_peer():
		print("GAMEUI LOADOUT | no multiplayer peer")
		return

	var arena := get_node_or_null("/root/TestArena/Arena")
	if arena == null:
		print("GAMEUI LOADOUT | Arena not found")
		return

	var local_peer_id := multiplayer.get_unique_id()
	arena.rpc_id(1, "request_set_loadout", local_peer_id, loadout_data)
	print("GAMEUI LOADOUT | request sent | peer ", local_peer_id, " -> ", loadout_data)

func send_player_name() -> void:
	if is_dedicated_server():
		return

	player_name_sent_to_server = false
	_try_send_player_name()

func _validate_expected_local_result(actual_text: String) -> void:
	var expected_result := LaunchOptions.get_expected_local_result()
	if expected_result == "":
		return

	if actual_text == expected_result:
		print("GAMEUI TEST | EXPECTED RESULT CONFIRMED: ", expected_result)
	else:
		push_error("GAMEUI TEST | EXPECTED RESULT MISMATCH | expected=%s actual=%s" % [expected_result, actual_text])

func _schedule_smoke_exit() -> void:
	if smoke_exit_scheduled:
		return

	var tree := get_tree()
	if tree == null:
		return

	smoke_exit_scheduled = true
	var exit_delay := LaunchOptions.get_smoke_exit_delay()
	print("GAMEUI | SMOKE EXIT SCHEDULED IN ", exit_delay, "s")
	tree.create_timer(exit_delay).timeout.connect(_quit_smoke_run)

func _quit_smoke_run() -> void:
	print("GAMEUI | SMOKE EXIT")
	get_tree().quit()
