extends Node3D

@export var beam_vfx_scene: PackedScene

@onready var player: Node = get_parent()
@onready var shoot_origin: Node3D = $"../ShootOrigin"
@onready var fp_shoot_origin: Node3D = $"../CameraRig/YawPivot/PitchPivot/FirstPersonHands/FPShootOrigin"

func _ready() -> void:
	if player != null and player.has_signal("shot_fired"):
		player.shot_fired.connect(_on_player_shot_fired)

func _on_player_shot_fired(shot_data: Dictionary) -> void:
	if beam_vfx_scene == null:
		push_warning("BeamRoot.gd: beam_vfx_scene is not assigned.")
		return

	var beam_instance := beam_vfx_scene.instantiate()
	if beam_instance == null:
		return

	add_child(beam_instance)

	var start_position: Vector3 = shoot_origin.global_position

	if fp_shoot_origin != null and player.has_method("get_combat_state"):
		var state := str(player.call("get_combat_state"))
		if state in ["AIMING", "FIRE", "HIT_CONFIRM", "MISS_CONFIRM"]:
			start_position = fp_shoot_origin.global_position

	var end_position: Vector3 = shot_data.get("impact_position", start_position)

	if beam_instance.has_method("play_beam"):
		beam_instance.call("play_beam", start_position, end_position, bool(shot_data.get("hit", false)))
