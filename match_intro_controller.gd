extends Node3D

signal intro_finished

@export var cut_pause_time: float = 0.2
@export var spike_rise_time: float = 1.0
@export var cracked_hold_time: float = 0.45
@export var cracked_shake_time: float = 0.75
@export var exploded_hold_time: float = 0.55

@export var player_hidden_y_offset: float = -2.0
@export var spike_start_y_offset: float = -2.0
@export var intro_look_height: float = 1.0

@export var allow_manual_test_trigger: bool = false

@onready var intro_camera_rig: Node3D = $IntroCameraRig
@onready var orbit_yaw: Node3D = $IntroCameraRig/OrbitYaw
@onready var orbit_pitch: Node3D = $IntroCameraRig/OrbitYaw/OrbitPitch
@onready var intro_camera: Camera3D = $IntroCameraRig/OrbitYaw/OrbitPitch/IntroCamera

@onready var player_egg_root: Node3D = $EggRoot
@onready var player_egg_whole: Node3D = $EggRoot/EggWhole
@onready var player_egg_cracked: Node3D = $EggRoot/EggCracked
@onready var player_egg_exploded: Node3D = $EggRoot/EggExploded
@onready var player_burst_particles: GPUParticles3D = $EggRoot/BurstParticles

@onready var enemy_egg_root: Node3D = $EnemyEggRoot
@onready var enemy_egg_whole: Node3D = $EnemyEggRoot/EnemyEggWhole
@onready var enemy_egg_cracked: Node3D = $EnemyEggRoot/EnemyEggCracked
@onready var enemy_egg_exploded: Node3D = $EnemyEggRoot/EnemyEggExploded
@onready var enemy_burst_particles: GPUParticles3D = $EnemyEggRoot/EnemyBurstParticles

@onready var player_spike_ring: Node3D = $SpikeRing
@onready var enemy_spike_ring: Node3D = $EnemySpikeRing
@onready var player_reveal_point: Node3D = $PlayerRevealPoint
@onready var enemy_reveal_point: Node3D = $EnemyRevealPoint
@onready var enemy_reveal_anchor: Node3D = $EnemyRevealAnchor
@onready var player_reveal_anchor: Node3D = $PlayerRevealAnchor

var intro_running: bool = false
var player_saved_spike_positions: Dictionary = {}
var enemy_saved_spike_positions: Dictionary = {}
var intro_camera_default_local_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	intro_camera_default_local_position = intro_camera.position
	_cache_specific_spike_positions(player_spike_ring, player_saved_spike_positions)
	_cache_specific_spike_positions(enemy_spike_ring, enemy_saved_spike_positions)
	_reset_intro_visuals()

func start_intro_for_players(local_player: Node3D, enemy_player: Node3D) -> void:
	if intro_running:
		return

	if local_player == null or enemy_player == null:
		push_warning("MatchIntroController: Missing local or enemy player.")
		_finish_intro(local_player, {}, {}, enemy_player)
		return

	intro_running = true
	_reset_intro_visuals()

	var local_original := {
		"transform": local_player.global_transform,
		"visible": local_player.visible
	}

	var enemy_original := {
		"transform": enemy_player.global_transform,
		"visible": enemy_player.visible
	}

	_prepare_player_for_intro(local_player, true)
	_prepare_player_for_intro(enemy_player, false)

	intro_camera.current = true

	await _show_enemy_hatch(enemy_player)
	await _show_player_hatch(local_player)

	_finish_intro(local_player, local_original, enemy_original, enemy_player)

func _prepare_player_for_intro(player: Node3D, is_local: bool) -> void:
	if player == null:
		return

	if player.has_method("set_match_active"):
		player.call("set_match_active", false)

	if player.has_method("set_duel_over"):
		player.call("set_duel_over", true)

	if is_local:
		player.global_transform = player_reveal_point.global_transform
		player.global_position.y += player_hidden_y_offset
		player.visible = false
	else:
		player.global_transform = enemy_reveal_point.global_transform
		player.global_position.y += player_hidden_y_offset
		player.visible = false

func _show_enemy_hatch(enemy_player: Node3D) -> void:
	_hide_enemy_egg_visuals()
	_reset_spikes(enemy_spike_ring, enemy_saved_spike_positions)
	_set_spike_ring_visible(enemy_spike_ring, false)

	enemy_player.global_transform = enemy_reveal_point.global_transform
	enemy_player.global_position.y += player_hidden_y_offset
	enemy_player.visible = false

	_set_node_to_marker_preserve_scale(enemy_egg_root, enemy_reveal_point)
	enemy_egg_root.global_position.y += player_hidden_y_offset
	enemy_egg_root.visible = false

	_set_camera_from_anchor(enemy_reveal_anchor, enemy_reveal_point)

	await get_tree().process_frame

	_set_spike_ring_visible(enemy_spike_ring, true)
	_set_enemy_egg_state_whole()

	await _rise_egg_and_spikes(
		enemy_egg_root,
		enemy_reveal_point.global_position.y,
		enemy_spike_ring,
		enemy_saved_spike_positions
	)

	_set_enemy_egg_state_cracked()
	await _shake_specific_egg(enemy_egg_cracked)

	_set_enemy_egg_state_exploded()
	if enemy_burst_particles != null:
		enemy_burst_particles.restart()

	enemy_player.global_transform = enemy_reveal_point.global_transform
	enemy_player.visible = true

	await get_tree().create_timer(exploded_hold_time).timeout

	_hide_enemy_egg_visuals()
	_set_spike_ring_visible(enemy_spike_ring, false)

	await get_tree().create_timer(cut_pause_time).timeout

func _show_player_hatch(local_player: Node3D) -> void:
	_hide_player_egg_visuals()
	_reset_spikes(player_spike_ring, player_saved_spike_positions)
	_set_spike_ring_visible(player_spike_ring, false)

	local_player.global_transform = player_reveal_point.global_transform
	local_player.global_position.y += player_hidden_y_offset
	local_player.visible = false

	_set_node_to_marker_preserve_scale(player_egg_root, player_reveal_point)
	player_egg_root.global_position.y += player_hidden_y_offset
	player_egg_root.visible = false

	_set_camera_from_anchor(player_reveal_anchor, player_reveal_point)

	await get_tree().process_frame

	_set_spike_ring_visible(player_spike_ring, true)
	_set_player_egg_state_whole()

	await _rise_egg_and_spikes(
		player_egg_root,
		player_reveal_point.global_position.y,
		player_spike_ring,
		player_saved_spike_positions
	)

	_set_player_egg_state_cracked()
	await _shake_specific_egg(player_egg_cracked)

	_set_player_egg_state_exploded()
	if player_burst_particles != null:
		player_burst_particles.restart()

	local_player.global_transform = player_reveal_point.global_transform
	local_player.visible = true

	await get_tree().create_timer(exploded_hold_time).timeout

	_hide_player_egg_visuals()
	_set_spike_ring_visible(player_spike_ring, false)

	await get_tree().create_timer(cut_pause_time).timeout

func _set_camera_from_anchor(anchor: Node3D, look_target: Node3D) -> void:
	if anchor == null or look_target == null:
		return

	orbit_yaw.global_transform = anchor.global_transform
	orbit_pitch.rotation = Vector3.ZERO
	intro_camera.position = intro_camera_default_local_position
	intro_camera.look_at(
		look_target.global_transform.origin + Vector3(0.0, intro_look_height, 0.0),
		Vector3.UP
	)

func _rise_egg_and_spikes(egg_root: Node3D, target_y: float, ring: Node3D, cache: Dictionary) -> void:
	if egg_root == null:
		return

	var tween: Tween = create_tween()
	tween.parallel().tween_property(egg_root, "global_position:y", target_y, spike_rise_time)

	if ring != null:
		for child in ring.get_children():
			if child is Node3D:
				var node: Node3D = child as Node3D
				var saved_local_y: float = float(cache.get(node.get_path(), node.position.y))
				tween.parallel().tween_property(node, "position:y", saved_local_y, spike_rise_time)

	await tween.finished

func _finish_intro(local_player: Node3D, local_original: Dictionary, enemy_original: Dictionary, enemy_player: Node3D = null) -> void:
	if local_player != null:
		if local_original.has("transform"):
			local_player.global_transform = local_original["transform"]
		if local_original.has("visible"):
			local_player.visible = bool(local_original["visible"])

		var gameplay_camera: Camera3D = local_player.get_node_or_null("CameraRig/YawPivot/PitchPivot/Camera3D")
		if gameplay_camera != null:
			gameplay_camera.current = true

		if local_player.has_method("set_duel_over"):
			local_player.call("set_duel_over", false)

		if local_player.has_method("set_match_active"):
			local_player.call("set_match_active", true)

	if enemy_player != null:
		if enemy_original.has("transform"):
			enemy_player.global_transform = enemy_original["transform"]
		if enemy_original.has("visible"):
			enemy_player.visible = bool(enemy_original["visible"])

		if enemy_player.has_method("set_duel_over"):
			enemy_player.call("set_duel_over", false)

		if enemy_player.has_method("set_match_active"):
			enemy_player.call("set_match_active", true)

	_reset_intro_visuals()

	intro_running = false
	intro_finished.emit()

func _input(event: InputEvent) -> void:
	if not allow_manual_test_trigger:
		return

	if not OS.is_debug_build():
		return

	if event.is_action_pressed("ui_accept"):
		var arena := get_parent()
		if arena == null:
			return

		if not arena.has_method("get_spawned_player_for_peer"):
			return

		var local_peer_id := multiplayer.get_unique_id()
		var local_player: Node3D = arena.call("get_spawned_player_for_peer", local_peer_id) as Node3D

		var enemy_player: Node3D = local_player
		if "spawned_players" in arena:
			for peer_id in arena.spawned_players.keys():
				if int(peer_id) != local_peer_id:
					enemy_player = arena.spawned_players[peer_id] as Node3D
					break

		if local_player != null and enemy_player != null:
			start_intro_for_players(local_player, enemy_player)

func _shake_specific_egg(egg_node: Node3D) -> void:
	if egg_node == null:
		return

	var original_rotation: Vector3 = egg_node.rotation
	var original_scale: Vector3 = egg_node.scale
	var elapsed: float = 0.0

	while elapsed < cracked_shake_time:
		egg_node.rotation.x = randf_range(-0.06, 0.06)
		egg_node.rotation.z = randf_range(-0.06, 0.06)
		egg_node.scale = original_scale * randf_range(0.98, 1.04)

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	egg_node.rotation = original_rotation
	egg_node.scale = original_scale

	await get_tree().create_timer(cracked_hold_time).timeout

func _set_node_to_marker_preserve_scale(node: Node3D, marker: Node3D) -> void:
	if node == null or marker == null:
		return

	node.global_position = marker.global_position
	node.global_rotation = marker.global_rotation

func _cache_specific_spike_positions(ring: Node3D, cache: Dictionary) -> void:
	cache.clear()
	if ring == null:
		return

	for child in ring.get_children():
		if child is Node3D:
			var node: Node3D = child as Node3D
			cache[node.get_path()] = node.position.y

func _reset_spikes(ring: Node3D, cache: Dictionary) -> void:
	if ring == null:
		return

	for child in ring.get_children():
		if child is Node3D:
			var node: Node3D = child as Node3D
			var target_y: float = float(cache.get(node.get_path(), node.position.y))
			node.position.y = target_y + spike_start_y_offset

func _set_spike_ring_visible(ring: Node3D, is_visible: bool) -> void:
	if ring == null:
		return

	ring.visible = is_visible
	for child in ring.get_children():
		if child is Node3D:
			(child as Node3D).visible = is_visible

func _reset_intro_visuals() -> void:
	_reset_spikes(player_spike_ring, player_saved_spike_positions)
	_reset_spikes(enemy_spike_ring, enemy_saved_spike_positions)

	_set_spike_ring_visible(player_spike_ring, false)
	_set_spike_ring_visible(enemy_spike_ring, false)

	_hide_player_egg_visuals()
	_hide_enemy_egg_visuals()

func _hide_player_egg_visuals() -> void:
	if player_egg_root != null:
		player_egg_root.visible = false
	if player_egg_whole != null:
		player_egg_whole.visible = false
	if player_egg_cracked != null:
		player_egg_cracked.visible = false
	if player_egg_exploded != null:
		player_egg_exploded.visible = false

func _hide_enemy_egg_visuals() -> void:
	if enemy_egg_root != null:
		enemy_egg_root.visible = false
	if enemy_egg_whole != null:
		enemy_egg_whole.visible = false
	if enemy_egg_cracked != null:
		enemy_egg_cracked.visible = false
	if enemy_egg_exploded != null:
		enemy_egg_exploded.visible = false

func _set_player_egg_state_whole() -> void:
	if player_egg_root != null:
		player_egg_root.visible = true
	if player_egg_whole != null:
		player_egg_whole.visible = true
	if player_egg_cracked != null:
		player_egg_cracked.visible = false
	if player_egg_exploded != null:
		player_egg_exploded.visible = false

func _set_player_egg_state_cracked() -> void:
	if player_egg_root != null:
		player_egg_root.visible = true
	if player_egg_whole != null:
		player_egg_whole.visible = false
	if player_egg_cracked != null:
		player_egg_cracked.visible = true
	if player_egg_exploded != null:
		player_egg_exploded.visible = false

func _set_player_egg_state_exploded() -> void:
	if player_egg_root != null:
		player_egg_root.visible = true
	if player_egg_whole != null:
		player_egg_whole.visible = false
	if player_egg_cracked != null:
		player_egg_cracked.visible = false
	if player_egg_exploded != null:
		player_egg_exploded.visible = true

func _set_enemy_egg_state_whole() -> void:
	if enemy_egg_root != null:
		enemy_egg_root.visible = true
	if enemy_egg_whole != null:
		enemy_egg_whole.visible = true
	if enemy_egg_cracked != null:
		enemy_egg_cracked.visible = false
	if enemy_egg_exploded != null:
		enemy_egg_exploded.visible = false

func _set_enemy_egg_state_cracked() -> void:
	if enemy_egg_root != null:
		enemy_egg_root.visible = true
	if enemy_egg_whole != null:
		enemy_egg_whole.visible = false
	if enemy_egg_cracked != null:
		enemy_egg_cracked.visible = true
	if enemy_egg_exploded != null:
		enemy_egg_exploded.visible = false

func _set_enemy_egg_state_exploded() -> void:
	if enemy_egg_root != null:
		enemy_egg_root.visible = true
	if enemy_egg_whole != null:
		enemy_egg_whole.visible = false
	if enemy_egg_cracked != null:
		enemy_egg_cracked.visible = false
	if enemy_egg_exploded != null:
		enemy_egg_exploded.visible = true
