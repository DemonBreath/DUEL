extends CharacterBody3D

@export var account_id: String = "enemy_dummy"
@export var max_health: int = 100
@export var destroy_on_death: bool = true
@export var death_delay: float = 0.05
@export var flash_duration: float = 0.10
@export var fall_gravity: float = 24.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var current_health: int = 100
var is_dead: bool = false
var hit_flash_timer: float = 0.0
var base_material: Material = null
var flash_material: StandardMaterial3D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("damageable")

	if mesh_instance != null and mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		base_material = mesh_instance.get_active_material(0)
		_build_flash_material()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= fall_gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	move_and_slide()

	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0:
			_restore_material()

func _build_flash_material() -> void:
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.15, 0.15, 1.0)
	flash_material.emission_energy_multiplier = 1.4
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

func get_account_id() -> String:
	return account_id

func get_current_health() -> int:
	return current_health

func receive_damage(amount: int, attacker_account_id: String = "") -> void:
	if is_dead:
		return
	if amount <= 0:
		return

	current_health = max(current_health - amount, 0)
	print("DUMMY HIT | health: ", current_health, " | attacker: ", attacker_account_id)

	_flash_hit()

	if current_health <= 0:
		die()

func _flash_hit() -> void:
	if mesh_instance == null or flash_material == null:
		return
	if mesh_instance.mesh == null:
		return
	if mesh_instance.mesh.get_surface_count() <= 0:
		return

	mesh_instance.set_surface_override_material(0, flash_material)
	hit_flash_timer = flash_duration

func _restore_material() -> void:
	if mesh_instance == null:
		return
	if mesh_instance.mesh == null:
		return
	if mesh_instance.mesh.get_surface_count() <= 0:
		return

	mesh_instance.set_surface_override_material(0, null)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	print("DUMMY DIED")

	if collision_shape != null:
		collision_shape.disabled = true

	_restore_material()

	if destroy_on_death:
		var timer := get_tree().create_timer(death_delay)
		await timer.timeout
		queue_free()
