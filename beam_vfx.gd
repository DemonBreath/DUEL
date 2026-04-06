extends Node3D

@export var beam_duration: float = 0.5
@export var beam_width: float = 1.0
@export var beam_height: float = 1.0

@onready var beam_pivot: Node3D = $BeamPivot

func play_beam(start_position: Vector3, end_position: Vector3, _is_hit: bool) -> void:
	print("Beam pivot global: ", beam_pivot.global_position)
	print("BeamVFX play_beam called")

	global_position = start_position
	look_at(end_position, Vector3.UP, true)

	var distance := start_position.distance_to(end_position)
	print("distance = ", distance)

	# IMPORTANT: pivot stays at origin now
	beam_pivot.position = Vector3.ZERO
	beam_pivot.scale = Vector3(beam_width, beam_height, max(distance, 0.01))

	beam_pivot.visible = true
	visible = true

	var timer := get_tree().create_timer(beam_duration)
	await timer.timeout
	queue_free()
