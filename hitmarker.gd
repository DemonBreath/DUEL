extends Control

@export var show_time: float = 0.04
@export var fade_time: float = 0.08
@export var hit_scale: float = 1.0

@onready var icon: TextureRect = $Icon
@onready var audio: AudioStreamPlayer = $Audio

var _player: Node = null
var _hold_timer: float = 0.0
var _fade_timer: float = 0.0

func _ready() -> void:
	visible = true

	if icon != null:
		icon.modulate.a = 0.0
		icon.scale = Vector2.ONE * hit_scale

	_center_icon()

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_connect_to_player(players[0])

func _process(delta: float) -> void:
	_center_icon()

	if _player == null:
		var players := get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_connect_to_player(players[0])

	if _hold_timer > 0.0:
		_hold_timer -= delta
		if _hold_timer <= 0.0:
			_fade_timer = fade_time

	elif _fade_timer > 0.0:
		_fade_timer -= delta
		var t: float = max(_fade_timer / fade_time, 0.0)

		if icon != null:
			icon.modulate.a = t
			icon.scale = Vector2.ONE * hit_scale

func _connect_to_player(player: Node) -> void:
	if player == null:
		return
	if _player == player:
		return

	_player = player

	if _player.has_signal("shot_hit") and not _player.shot_hit.is_connected(_on_player_shot_hit):
		_player.shot_hit.connect(_on_player_shot_hit)

func _on_player_shot_hit(shot_data: Dictionary) -> void:
	var target_account_id := str(shot_data.get("target_account_id", ""))
	if target_account_id == "":
		return

	if icon != null:
		icon.modulate.a = 1.0
		icon.scale = Vector2.ONE * hit_scale

	_hold_timer = show_time
	_fade_timer = 0.0

	if audio != null and audio.stream != null:
		audio.play()

func _center_icon() -> void:
	if icon == null:
		return

	icon.custom_minimum_size = Vector2(48, 48)
	icon.size = Vector2(48, 48)
	icon.position = (size * 0.5) - (icon.size * 0.5)
