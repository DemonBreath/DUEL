extends CharacterBody3D

signal shot_fired(shot_data)
signal shot_hit(shot_data)
signal shot_missed(shot_data)
signal health_changed(current_health, max_health)
signal player_died(account_id)
signal aim_state_changed(new_state)
signal crosshair_visibility_requested(is_visible)

const STATE_FREE := "FREE"
const STATE_ENTER_AIM := "ENTER_AIM"
const STATE_AIMING := "AIMING"
const STATE_FIRE := "FIRE"
const STATE_HIT_CONFIRM := "HIT_CONFIRM"
const STATE_MISS_CONFIRM := "MISS_CONFIRM"
const STATE_EXIT_AIM := "EXIT_AIM"
const STATE_DEAD := "DEAD"

@export_category("Mouse / Look")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch_deg: float = -70.0
@export var max_pitch_deg: float = 70.0

@export_category("Movement")
@export var base_move_speed: float = 8.5
@export var base_acceleration: float = 14.0
@export var base_deceleration: float = 18.0
@export var base_air_acceleration: float = 7.0
@export var base_air_deceleration: float = 5.0
@export var jump_velocity: float = 9.0
@export var gravity_scale: float = 0.72
@export var fall_gravity_scale: float = 0.92
@export var terminal_velocity: float = 30.0
@export var air_control: float = 0.9
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_category("Jump Animation")
@export var jump_anim_lock_duration: float = 0.22

@export_category("Aim / Fire")
@export var enter_aim_duration: float = 2.6
@export var fire_trigger_delay: float = 0.28
@export var post_fire_lock_duration: float = .9
@export var exit_aim_duration: float = 3.2
@export var shot_recovery_duration: float = 0.0
@export var shot_cooldown_seconds: float = 0.45
@export var shot_range: float = 200.0
@export var shot_damage: int = 100
@export var start_bullets: int = 6
@export var ammo_gain_on_player_kill: int = 6
@export var freeze_vertical_momentum_on_shot: bool = false

@export_category("Combat / Health")
@export var base_max_health: int = 100
@export var invulnerable_after_spawn_time: float = 0.0

@export_category("Animation Hooks")
@export var use_animation_player: bool = true
@export var idle_anim_name: StringName = "idle"
@export var move_anim_name: StringName = "move"
@export var jump_anim_name: StringName = "jump"
@export var hurt_anim_name: StringName = "hurt"
@export var shoot_anim_name: StringName = "fire"
@export var death_anim_name: StringName = "death"

@export_category("Camera Anchors")
@export var third_person_offset: Vector3 = Vector3(0.0, 1.55, 4.2)
@export var first_person_offset: Vector3 = Vector3(0.20, 1.42, -0.6)
@export var zoom_in_speed: float = 30
@export var zoom_out_speed: float = 60

@onready var camera_rig: Node3D = $CameraRig
@onready var yaw_pivot: Node3D = $CameraRig/YawPivot
@onready var pitch_pivot: Node3D = $CameraRig/YawPivot/PitchPivot
@onready var third_person_anchor: Node3D = $CameraRig/YawPivot/PitchPivot/ThirdPersonAnchor
@onready var first_person_anchor: Node3D = $CameraRig/YawPivot/PitchPivot/FirstPersonAnchor
@onready var camera: Camera3D = $CameraRig/YawPivot/PitchPivot/Camera3D
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var first_person_hands: Node3D = get_node_or_null("CameraRig/YawPivot/PitchPivot/FirstPersonHands")
@onready var beam_visual: Node3D = get_node_or_null("CameraRig/YawPivot/PitchPivot/FirstPersonHands/BeamVisual")

var remote_target_transform: Transform3D
var remote_initialized: bool = false

var account_id: String = ""
var match_active: bool = false

var combat_state: String = STATE_FREE
var yaw: float = 0.0
var pitch: float = 0.0

var state_timer: float = 0.0
var shot_cooldown_timer: float = 0.0
var spawn_invuln_timer: float = 0.0

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jump_anim_lock_timer: float = 0.0
var was_grounded_last_frame: bool = true

var current_health: int = 100
var max_health: int = 100
var current_ammo: int = 0

var duel_is_over: bool = false

var loadout_data: Dictionary = {}
var stat_move_speed: float = 8.5
var stat_jump_force: float = 9.0
var stat_aim_move_multiplier: float = 0.0
var stat_shot_cooldown: float = 1.0

var last_move_input: Vector2 = Vector2.ZERO
var last_shot_data: Dictionary = {
	"shooter_account_id": "",
	"hit": false,
	"target_account_id": "",
	"target_position": Vector3.ZERO,
	"origin_position": Vector3.ZERO,
	"impact_position": Vector3.ZERO,
	"damage": 0
}

func is_dedicated_server() -> bool:
	return DisplayServer.get_name() == "headless"

func is_local_player() -> bool:
	if is_dedicated_server():
		return false
	return multiplayer.get_unique_id() == get_multiplayer_authority()

func _ready() -> void:
	add_to_group("player")

	if is_local_player():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	print(name, " | local_player = ", is_local_player(), " | authority = ", get_multiplayer_authority(), " | unique_id = ", multiplayer.get_unique_id())

	third_person_anchor.position = third_person_offset
	first_person_anchor.position = first_person_offset
	camera.position = third_person_anchor.position

	yaw = rotation.y
	pitch = pitch_pivot.rotation.x

	current_ammo = start_bullets
	_apply_default_stats()
	_reset_health()

	spawn_invuln_timer = invulnerable_after_spawn_time
	was_grounded_last_frame = is_on_floor()

	if first_person_hands != null:
		first_person_hands.visible = false

	if beam_visual != null:
		beam_visual.visible = false

	_emit_combat_state()
	_emit_health()
	_update_crosshair_visibility()
	_play_idle_or_move_animation(Vector2.ZERO)

	match_active = true

	_update_first_person_hands_visibility()
	_update_beam_visual_visibility()

	if not is_local_player():
		if camera != null:
			camera.current = false
		if first_person_hands != null:
			first_person_hands.visible = false

	if is_dedicated_server():
		if camera != null:
			camera.current = false
		if first_person_hands != null:
			first_person_hands.visible = false
			

func _unhandled_input(event: InputEvent) -> void:
	if is_dedicated_server():
		return

	if not is_local_player():
		return

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(
			pitch,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if combat_state == STATE_DEAD:
		return

	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

@rpc("unreliable", "any_peer")
func sync_transform_from_owner(new_transform: Transform3D) -> void:
	if is_local_player():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		return

	remote_target_transform = new_transform

	if not remote_initialized:
		global_transform = new_transform
		remote_initialized = true

@rpc("unreliable", "any_peer")
func sync_anim_state_from_owner(anim_name: String) -> void:
	if is_local_player():
		return

	if anim_player != null and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

@rpc("call_remote", "any_peer")
func show_remote_shot_fx(origin: Vector3, impact_position: Vector3, did_hit: bool) -> void:
	if is_local_player():
		return

	print("REMOTE SHOT FX | ", name, " | hit=", did_hit)

	if beam_visual != null:
		beam_visual.visible = true
		beam_visual.global_position = origin

		var dir := impact_position - origin
		if dir.length() > 0.001:
			beam_visual.look_at(impact_position, Vector3.UP)

		await get_tree().create_timer(0.08).timeout

		if beam_visual != null:
			beam_visual.visible = false

func _physics_process(delta: float) -> void:
	if is_local_player():
		_update_timers(delta)
		_update_camera_rotation()

		if combat_state != STATE_DEAD:
			_handle_state_machine(delta)
		else:
			_process_dead_state(delta)

		_update_camera_position(delta)
		_update_animation_state()

		if multiplayer.has_multiplayer_peer():
			sync_transform_from_owner.rpc(global_transform)

			var anim_to_sync := ""
			if anim_player != null:
				anim_to_sync = anim_player.current_animation

			if anim_to_sync != "":
				sync_anim_state_from_owner.rpc(anim_to_sync)
	else:
		if remote_initialized:
			global_transform = global_transform.interpolate_with(
				remote_target_transform,
				min(delta * 12.0, 1.0)
			)

func _update_timers(delta: float) -> void:
	if shot_cooldown_timer > 0.0:
		shot_cooldown_timer -= delta

	if state_timer > 0.0:
		state_timer -= delta

	if spawn_invuln_timer > 0.0:
		spawn_invuln_timer -= delta

	if jump_anim_lock_timer > 0.0:
		jump_anim_lock_timer -= delta

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta

func _handle_state_machine(delta: float) -> void:
	match combat_state:
		STATE_FREE:
			_process_free_state(delta)
		STATE_ENTER_AIM:
			_process_enter_aim_state(delta)
		STATE_AIMING:
			_process_aiming_state(delta)
		STATE_FIRE:
			_process_fire_state(delta)
		STATE_HIT_CONFIRM:
			_process_hit_confirm_state(delta)
		STATE_MISS_CONFIRM:
			_process_miss_confirm_state(delta)
		STATE_EXIT_AIM:
			_process_exit_aim_state(delta)
		STATE_DEAD:
			_process_dead_state(delta)

func _process_free_state(delta: float) -> void:
	if not match_active or duel_is_over:
		_process_movement(delta, 0.0, true)
		return

	_process_movement(delta, 1.0, false)
	_process_jump()

	if _can_start_aim():
		_play_named_animation(shoot_anim_name)
		_enter_state(STATE_ENTER_AIM, enter_aim_duration)
		_freeze_momentum_for_shot()

func _process_enter_aim_state(delta: float) -> void:
	if not match_active or duel_is_over:
		force_exit_aim()
		return

	_process_movement(delta, 0.0, true)

	if state_timer <= 0.0:
		_enter_state(STATE_AIMING, fire_trigger_delay)

func _process_aiming_state(delta: float) -> void:
	if not match_active or duel_is_over:
		force_exit_aim()
		return

	_process_movement(delta, stat_aim_move_multiplier, true)

	if state_timer <= 0.0:
		_fire_shot()

func _process_fire_state(delta: float) -> void:
	_process_movement(delta, 0.0, true)

	if state_timer <= 0.0:
		_enter_state(STATE_EXIT_AIM, exit_aim_duration)

func _process_hit_confirm_state(delta: float) -> void:
	_process_movement(delta, 0.0, true)

	if state_timer <= 0.0:
		_enter_state(STATE_EXIT_AIM, exit_aim_duration)

func _process_miss_confirm_state(delta: float) -> void:
	_process_movement(delta, 0.0, true)

	if state_timer <= 0.0:
		_enter_state(STATE_EXIT_AIM, exit_aim_duration)

func _process_exit_aim_state(delta: float) -> void:
	_process_movement(delta, 0.25, false)

	if state_timer <= 0.0:
		_enter_state(STATE_FREE, 0.0)

func _process_dead_state(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, base_deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, base_deceleration * delta)
	move_and_slide()

func _process_movement(delta: float, move_multiplier: float, suppress_new_horizontal_input: bool) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	last_move_input = input_dir

	var world_dir := Vector3.ZERO
	if input_dir.length() > 0.001:
		var forward := -yaw_pivot.global_transform.basis.z
		var right := yaw_pivot.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		world_dir = (right * input_dir.x - forward * input_dir.y).normalized()

	var target_speed := stat_move_speed * move_multiplier
	var accel := base_acceleration
	var decel := base_deceleration

	if not is_on_floor():
		accel = base_air_acceleration
		decel = base_air_deceleration

	var target_velocity_xz := Vector3.ZERO

	if not suppress_new_horizontal_input:
		target_velocity_xz = world_dir * target_speed

	var current_velocity_xz := Vector3(velocity.x, 0.0, velocity.z)

	if target_velocity_xz.length() > 0.001:
		var use_accel := accel
		if not is_on_floor():
			use_accel *= air_control
		current_velocity_xz = current_velocity_xz.move_toward(target_velocity_xz, use_accel * delta)
	else:
		current_velocity_xz = current_velocity_xz.move_toward(Vector3.ZERO, decel * delta)

	velocity.x = current_velocity_xz.x
	velocity.z = current_velocity_xz.z

	_apply_gravity(delta)
	move_and_slide()

func _process_jump() -> void:
	if jump_buffer_timer <= 0.0:
		return

	if is_on_floor() or coyote_timer > 0.0:
		velocity.y = stat_jump_force
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jump_anim_lock_timer = jump_anim_lock_duration
		_play_named_animation(jump_anim_name)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var applied_gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
		if velocity.y > 0.0:
			velocity.y -= applied_gravity * gravity_scale * delta
		else:
			velocity.y -= applied_gravity * fall_gravity_scale * delta

		if velocity.y < -terminal_velocity:
			velocity.y = -terminal_velocity
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

func _update_camera_rotation() -> void:
	rotation.y = yaw
	pitch_pivot.rotation.x = pitch

func _update_camera_position(delta: float) -> void:
	var target: Vector3 = third_person_anchor.position

	match combat_state:
		STATE_AIMING, STATE_FIRE, STATE_HIT_CONFIRM, STATE_MISS_CONFIRM:
			target = first_person_anchor.position
		STATE_ENTER_AIM, STATE_EXIT_AIM, STATE_FREE, STATE_DEAD:
			target = third_person_anchor.position

	var speed := zoom_out_speed
	if target == first_person_anchor.position:
		speed = zoom_in_speed

	camera.position = camera.position.lerp(target, speed * delta)

func _can_start_aim() -> bool:
	if duel_is_over:
		return false
	if not match_active:
		return false
	if combat_state != STATE_FREE:
		return false
	if shot_cooldown_timer > 0.0:
		return false
	if current_ammo <= 0:
		return false
	return Input.is_action_just_pressed("fire")

func _fire_shot() -> void:
	if current_ammo <= 0:
		_enter_state(STATE_EXIT_AIM, exit_aim_duration)
		return

	current_ammo -= 1
	shot_cooldown_timer = stat_shot_cooldown
	_update_crosshair_visibility()

	var origin: Vector3 = camera.global_transform.origin
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()

	var local_shot_data: Dictionary = {
		"shooter_account_id": account_id,
		"hit": false,
		"target_account_id": "",
		"target_position": Vector3.ZERO,
		"origin_position": origin,
		"impact_position": origin + direction * shot_range,
		"damage": shot_damage
	}

	last_shot_data = local_shot_data
	emit_signal("shot_fired", local_shot_data)

	print("SHOT FIRED | ammo now: ", current_ammo)

	if multiplayer.is_server():
		_process_shot_on_host(origin, direction)
	else:
		rpc_id(1, "request_fire_to_host", origin, direction)

	_enter_state(STATE_FIRE, post_fire_lock_duration)

func _freeze_momentum_for_shot() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	if freeze_vertical_momentum_on_shot:
		velocity.y = 0.0

func _enter_state(new_state: String, duration: float) -> void:
	print("STATE CHANGE | ", name, " -> ", new_state, " | duration: ", duration)
	combat_state = new_state
	state_timer = duration
	_emit_combat_state()
	_update_crosshair_visibility()
	_update_first_person_hands_visibility()
	_update_beam_visual_visibility()

func _emit_combat_state() -> void:
	emit_signal("aim_state_changed", combat_state)

func _update_crosshair_visibility() -> void:
	var crosshair_visible := combat_state in [
		STATE_AIMING,
		STATE_FIRE,
		STATE_HIT_CONFIRM,
		STATE_MISS_CONFIRM
	]
	emit_signal("crosshair_visibility_requested", crosshair_visible)

func _update_first_person_hands_visibility() -> void:
	if first_person_hands == null:
		return

	first_person_hands.visible = combat_state in [
		STATE_AIMING,
		STATE_FIRE,
		STATE_HIT_CONFIRM,
		STATE_MISS_CONFIRM
	]

func _update_beam_visual_visibility() -> void:
	if beam_visual == null:
		return

	beam_visual.visible = combat_state == STATE_FIRE

func _reset_health() -> void:
	max_health = int(loadout_data.get("stat_modifiers", {}).get("max_health", base_max_health))
	current_health = max_health

func _emit_health() -> void:
	emit_signal("health_changed", current_health, max_health)

func _update_animation_state() -> void:
	if not use_animation_player or anim_player == null:
		return

	if combat_state == STATE_DEAD:
		return

	if combat_state in [STATE_ENTER_AIM, STATE_AIMING, STATE_FIRE, STATE_EXIT_AIM, STATE_HIT_CONFIRM, STATE_MISS_CONFIRM]:
		was_grounded_last_frame = is_on_floor()
		return

	var grounded := is_on_floor()

	if not grounded:
		was_grounded_last_frame = false
		return

	if grounded and not was_grounded_last_frame:
		jump_anim_lock_timer = 0.0

	if jump_anim_lock_timer > 0.0:
		was_grounded_last_frame = grounded
		return

	_play_idle_or_move_animation(last_move_input)
	was_grounded_last_frame = grounded

func _play_idle_or_move_animation(input_dir: Vector2) -> void:
	if not use_animation_player or anim_player == null:
		return

	if input_dir.length() > 0.1:
		_play_named_animation(move_anim_name)
	else:
		_play_named_animation(idle_anim_name)

func _play_named_animation(anim_name: StringName) -> void:
	if not use_animation_player or anim_player == null:
		return
	if String(anim_name).is_empty():
		return
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation == String(anim_name) and anim_player.is_playing():
		return
	print("PLAY ANIM | ", name, " | ", anim_name)
	anim_player.play(anim_name)

func receive_damage(amount: int, attacker_account_id: String = "") -> void:
	apply_damage_from_host(amount, attacker_account_id)

@rpc("any_peer", "call_local")
func apply_damage_from_host(amount: int, attacker_account_id: String = "") -> void:
	if combat_state == STATE_DEAD:
		return
	if amount <= 0:
		return
	if spawn_invuln_timer > 0.0:
		return

	current_health = max(current_health - amount, 0)
	_emit_health()

	if current_health <= 0:
		_die(attacker_account_id)
	else:
		_play_named_animation(hurt_anim_name)

func _die(_attacker_account_id: String = "") -> void:
	if combat_state == STATE_DEAD:
		return

	current_health = 0
	current_ammo = 0
	_enter_state(STATE_DEAD, 0.0)
	_emit_health()
	_play_named_animation(death_anim_name)
	emit_signal("player_died", account_id)

func apply_loadout(loadout_data_in: Dictionary) -> void:
	loadout_data = loadout_data_in.duplicate(true)

	var mods: Dictionary = loadout_data.get("stat_modifiers", {})
	stat_move_speed = base_move_speed * float(mods.get("move_speed", 1.0))
	stat_jump_force = jump_velocity * float(mods.get("jump_force", 1.0))
	stat_aim_move_multiplier = float(mods.get("aim_move_multiplier", 0.0))
	stat_shot_cooldown = float(mods.get("shot_cooldown", 1.0))
	max_health = int(mods.get("max_health", base_max_health))
	current_health = min(current_health, max_health)
	if current_health <= 0:
		current_health = max_health

	_emit_health()

func _apply_default_stats() -> void:
	stat_move_speed = base_move_speed
	stat_jump_force = jump_velocity
	stat_aim_move_multiplier = 0.0
	stat_shot_cooldown = 1.0
	max_health = base_max_health

func set_account_id(value: String) -> void:
	account_id = value

func get_account_id() -> String:
	return account_id

func set_match_active(is_active: bool) -> void:
	match_active = is_active
	print("SET MATCH ACTIVE | ", name, " -> ", match_active)

	if not match_active and combat_state != STATE_DEAD:
		force_exit_aim()
		velocity.x = 0.0
		velocity.z = 0.0

func get_current_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func get_combat_state() -> String:
	return combat_state

func force_exit_aim() -> void:
	if combat_state == STATE_DEAD:
		return
	_enter_state(STATE_FREE, 0.0)
	camera.position = third_person_anchor.position
	velocity.x = 0.0
	velocity.z = 0.0

func add_ammo(amount: int) -> void:
	current_ammo += max(amount, 0)

func spend_all_ammo() -> void:
	current_ammo = 0

func get_current_ammo() -> int:
	return current_ammo

func set_current_ammo(value: int) -> void:
	current_ammo = max(value, 0)

@rpc("any_peer")
func request_fire_to_host(origin: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		print("FIRE REJECTED | sender mismatch | sender=", sender_id, " authority=", get_multiplayer_authority())
		return

	if combat_state == STATE_DEAD:
		print("FIRE REJECTED | dead player | ", name)
		return

	if not match_active or duel_is_over:
		print("FIRE REJECTED | match inactive or duel over | ", name)
		return

	_process_shot_on_host(origin, direction)

func _process_shot_on_host(origin: Vector3, direction: Vector3) -> void:
	var end: Vector3 = origin + direction * shot_range

	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.exclude = [self]
	params.collide_with_bodies = true
	params.collide_with_areas = true

	var result := get_world_3d().direct_space_state.intersect_ray(params)
	print("HOST RAYCAST RESULT: ", result)

	var shot_data: Dictionary = {
		"shooter_account_id": account_id,
		"hit": false,
		"target_account_id": "",
		"target_position": Vector3.ZERO,
		"origin_position": origin,
		"impact_position": end,
		"damage": shot_damage
	}

	if not result.is_empty():
		var collider: Object = result.get("collider")
		var hit_position: Vector3 = result.get("position", end)
		shot_data["impact_position"] = hit_position
		shot_data["target_position"] = hit_position

		var damage_target: Node = null

		if collider != null:
			damage_target = collider as Node

			while damage_target != null and not damage_target.has_method("receive_damage"):
				damage_target = damage_target.get_parent()

		if damage_target != null:
			print("DAMAGE TARGET FOUND: ", damage_target.name)
			print("SHOT BY: ", name, " | HIT: ", damage_target.name)
		else:
			print("NO DAMAGE TARGET FOUND")

		if damage_target != null and damage_target.has_method("get_account_id"):
			shot_data["target_account_id"] = str(damage_target.call("get_account_id"))

		print("SHOT DATA: ", shot_data)

		if damage_target != null and shot_data["target_account_id"] != "":
			if damage_target.has_method("apply_damage_from_host"):
				shot_data["hit"] = true
				damage_target.rpc("apply_damage_from_host", shot_damage, account_id)
			elif damage_target.has_method("receive_damage"):
				shot_data["hit"] = true
				damage_target.call("receive_damage", shot_damage, account_id)

		if damage_target != null and damage_target.has_method("get_current_health"):
			var hp_after := int(damage_target.call("get_current_health"))
			if hp_after <= 0 and shot_data["target_account_id"] != "":
				if is_local_player():
					add_ammo(ammo_gain_on_player_kill)
				else:
					rpc_id(get_multiplayer_authority(), "grant_kill_ammo_from_host", ammo_gain_on_player_kill)

	if is_local_player():
		confirm_shot_result_from_host(shot_data)
	else:
		rpc_id(get_multiplayer_authority(), "confirm_shot_result_from_host", shot_data)

@rpc("any_peer")
func confirm_shot_result_from_host(shot_data: Dictionary) -> void:
	if not is_local_player():
		return

	last_shot_data = shot_data

	if bool(shot_data["hit"]):
		emit_signal("shot_hit", shot_data)
	else:
		emit_signal("shot_missed", shot_data)

	show_remote_shot_fx.rpc(
		shot_data["origin_position"],
		shot_data["impact_position"],
		bool(shot_data["hit"])
	)

@rpc("any_peer")
func grant_kill_ammo_from_host(amount: int) -> void:
	if not is_local_player():
		return

	if duel_is_over:
		return

	add_ammo(amount)
	print("KILL CONFIRMED | ammo granted | ammo now: ", current_ammo)

func set_duel_over(is_over: bool) -> void:
	duel_is_over = is_over
	match_active = not is_over

	if duel_is_over:
		force_exit_aim()
		velocity = Vector3.ZERO

@rpc("any_peer", "call_local")
func set_duel_over_remote(is_over: bool) -> void:
	set_duel_over(is_over)

func reset_for_new_round(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	remote_target_transform = spawn_transform
	remote_initialized = true

	velocity = Vector3.ZERO

	duel_is_over = false
	match_active = false
	combat_state = STATE_FREE
	state_timer = 0.0
	shot_cooldown_timer = 0.0
	jump_buffer_timer = 0.0
	jump_anim_lock_timer = 0.0
	spawn_invuln_timer = invulnerable_after_spawn_time

	current_ammo = start_bullets
	_reset_health()
	_emit_health()

	camera.position = third_person_anchor.position
	_update_crosshair_visibility()
	_update_first_person_hands_visibility()
	_update_beam_visual_visibility()
	_play_named_animation(idle_anim_name)

	print("RESET FOR NEW ROUND | ", name)
	
func get_player_inventory() -> Node:
	return $PlayerInventory

func get_equipped_hat_id() -> String:
	var inventory: Node = $PlayerInventory
	if inventory == null:
		return ""

	if not inventory.has_method("get_equipped_item"):
		return ""

	return str(inventory.call("get_equipped_item", "head"))

func apply_hat_inventory_data(hat_data: Dictionary) -> void:
	var inventory: Node = $PlayerInventory
	if inventory == null:
		push_warning("Player | apply_hat_inventory_data failed | missing PlayerInventory")
		return

	if not inventory.has_method("setup_from_data"):
		push_warning("Player | apply_hat_inventory_data failed | inventory missing setup_from_data")
		return

	inventory.call("setup_from_data", hat_data)
	
func get_hat_inventory_data() -> Dictionary:
	var inventory: Node = $PlayerInventory
	if inventory == null:
		return {}

	if not inventory.has_method("to_data"):
		return {}

	return inventory.call("to_data")
