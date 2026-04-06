extends Node

signal inventory_changed
signal equipment_changed
signal item_equipped(slot_name: String, item_id: String)
signal item_unequipped(slot_name: String, item_id: String)
signal item_added(item_id: String)
signal item_removed(item_id: String)

var owned_items: Array[String] = []
var equipped := {
	"head": ""
}

func setup_from_data(data: Dictionary) -> void:
	owned_items.clear()

	var incoming_owned: Array = data.get("owned_items", [])
	for value in incoming_owned:
		owned_items.append(str(value))

	var incoming_equipped: Dictionary = data.get("equipped", {})
	equipped["head"] = str(incoming_equipped.get("head", ""))

	_emit_full_refresh()

func to_data() -> Dictionary:
	return {
		"owned_items": owned_items.duplicate(),
		"equipped": equipped.duplicate(true)
	}

func has_item(item_id: String) -> bool:
	return owned_items.has(item_id)

func add_item(item_id: String) -> bool:
	if item_id == "":
		return false

	if has_item(item_id):
		return false

	if not ItemDatabase.has_item_def(item_id):
		push_warning("PlayerInventory: Cannot add undefined item: %s" % item_id)
		return false

	owned_items.append(item_id)
	item_added.emit(item_id)
	inventory_changed.emit()
	return true

func remove_item(item_id: String) -> bool:
	if item_id == "":
		return false

	if not has_item(item_id):
		return false

	var slot_name: String = get_equipped_slot_for_item(item_id)
	if slot_name != "":
		unequip_slot(slot_name)

	owned_items.erase(item_id)
	item_removed.emit(item_id)
	inventory_changed.emit()
	return true

func equip_item(item_id: String) -> bool:
	if item_id == "":
		return false

	if not has_item(item_id):
		push_warning("PlayerInventory: Cannot equip item not owned: %s" % item_id)
		return false

	if not ItemDatabase.has_item_def(item_id):
		push_warning("PlayerInventory: Cannot equip undefined item: %s" % item_id)
		return false

	var slot_name: String = ItemDatabase.get_item_slot(item_id)
	if slot_name != "head":
		push_warning("PlayerInventory: Item has invalid slot: %s" % item_id)
		return false

	if equipped["head"] == item_id:
		return true

	if equipped["head"] != "":
		unequip_slot("head")

	equipped["head"] = item_id
	item_equipped.emit("head", item_id)
	equipment_changed.emit()
	return true

func unequip_slot(slot_name: String) -> bool:
	if slot_name != "head":
		return false

	var current_item_id: String = str(equipped["head"])
	if current_item_id == "":
		return false

	equipped["head"] = ""
	item_unequipped.emit("head", current_item_id)
	equipment_changed.emit()
	return true

func get_equipped_item(slot_name: String) -> String:
	if slot_name != "head":
		return ""
	return str(equipped["head"])

func get_equipped_slot_for_item(item_id: String) -> String:
	if str(equipped["head"]) == item_id:
		return "head"
	return ""

func get_stealable_equipped_items() -> Array[String]:
	var result: Array[String] = []
	var item_id: String = get_equipped_item("head")
	if item_id != "":
		result.append(item_id)
	return result

func has_equipped_hat() -> bool:
	return str(equipped["head"]) != ""

func ensure_minimum_hat() -> bool:
	if owned_items.size() > 0:
		return false

	var fallback_hat_id: String = ItemDatabase.FALLBACK_HAT_ID
	if fallback_hat_id == "":
		push_warning("PlayerInventory: No fallback hat configured.")
		return false

	var added: bool = add_item(fallback_hat_id)
	if added:
		equip_item(fallback_hat_id)
	return added

func ensure_equipped_hat() -> bool:
	if has_equipped_hat():
		return true

	if owned_items.is_empty():
		var granted: bool = ensure_minimum_hat()
		if not granted and owned_items.is_empty():
			return false

	var first_hat_id: String = str(owned_items[0])
	return equip_item(first_hat_id)

func owns_any_items() -> bool:
	return owned_items.size() > 0

func has_any_equipped_items() -> bool:
	return get_stealable_equipped_items().size() > 0

func clear_all() -> void:
	owned_items.clear()
	equipped["head"] = ""
	_emit_full_refresh()

func _emit_full_refresh() -> void:
	inventory_changed.emit()
	equipment_changed.emit()
