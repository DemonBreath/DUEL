extends Node3D

@export var inventory_path: NodePath
@export var head_socket_path: NodePath

var inventory: Node = null
var head_socket: Node3D = null
var current_head_visual: Node = null

func _ready() -> void:
	inventory = get_node_or_null(inventory_path)
	head_socket = get_node_or_null(head_socket_path) as Node3D

	if inventory == null:
		push_error("OutfitManager: Missing inventory node.")
		return

	if head_socket == null:
		push_error("OutfitManager: Missing HeadSocket node.")
		return

	if inventory.has_signal("equipment_changed"):
		inventory.connect("equipment_changed", Callable(self, "_refresh_head_visual"))

	_refresh_head_visual()

func _refresh_head_visual() -> void:
	_clear_head_visual()

	if not inventory.has_method("get_equipped_item"):
		return

	var item_id: String = str(inventory.call("get_equipped_item", "head"))
	if item_id == "":
		return

	if not ItemDatabase.has_item_def(item_id):
		push_warning("OutfitManager: Undefined equipped item: %s" % item_id)
		return

	var scene_path: String = ItemDatabase.get_item_scene_path(item_id)
	if scene_path == "":
		push_warning("OutfitManager: Missing scene path for item: %s" % item_id)
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_warning("OutfitManager: Failed to load scene for item: %s | path=%s" % [item_id, scene_path])
		return

	var instance: Node = packed.instantiate()
	if instance == null:
		push_warning("OutfitManager: Failed to instance item scene: %s" % item_id)
		return

	head_socket.add_child(instance)
	current_head_visual = instance

func _clear_head_visual() -> void:
	if current_head_visual != null and is_instance_valid(current_head_visual):
		current_head_visual.queue_free()
	current_head_visual = null
