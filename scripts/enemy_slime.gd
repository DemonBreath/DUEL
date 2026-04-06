extends CharacterBody3D

@export var move_speed: float = 2.5
@export var acceleration: float = 8.0
@export var health: int = 3
@export var gravity_scale: float = 1.0
@export var stop_distance: float = 1.2
@export var detection_range: float = 9999.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var player: Node3D = null
var is_dead: bool = false

@onready var sprite_root: Node3D = $SpriteRoot
@onready var sprite_3d: Sprite3D = $SpriteRoot/Sprite3D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D

	if sprite_3d:
		sprite_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return

	var to_player: Vector3 = player.global_transform.origin - global_transform.origin
	var flat_to_player: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	var distance: float = flat_to_player.length()

	if distance <= detection_range:
		_face_player()

		if distance > stop_distance:
			var dir: Vector3 = flat_to_player.normalized()
			velocity.x = move_toward(velocity.x, dir.x * move_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, dir.z * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta
	else:
		velocity.y = 0.0

	move_and_slide()

func _face_player() -> void:
	if player == null:
		return

	var player_pos: Vector3 = player.global_transform.origin
	player_pos.y = global_transform.origin.y
	look_at(player_pos, Vector3.UP)

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount

	if health <= 0:
		die()

func die() -> void:
	is_dead = true
	queue_free()
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return

	var to_player: Vector3 = player.global_transform.origin - global_transform.origin
	var flat_to_player := Vector3(to_player.x, 0.0, to_player.z)
	var distance := flat_to_player.length()

	if distance <= detection_range:
		_face_player()

		if distance > stop_distance:
			var dir := flat_to_player.normalized()
			velocity.x = move_toward(velocity.x, dir.x * move_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, dir.z * move_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func _face_player() -> void:
	if player == null:
		return

	var player_pos := player.global_transform.origin
	var own_pos := global_transform.origin
	player_pos.y = own_pos.y

	look_at(player_pos, Vector3.UP)


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount

	if health <= 0:
		die()


func die() -> void:
	is_dead = true
	queue_free()
