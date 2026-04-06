extends Node

const SAVE_PATH := "user://hat_profile.json"

const DEFAULT_ACCOUNT_ID := "player_001"
const DEFAULT_USERNAME := "Player"

const DEFAULT_HAT_INVENTORY := {
	"owned_items": [],
	"equipped": {
		"head": ""
	}
}

var local_profile_data: Dictionary = {}
var local_profile_loaded: bool = false

func _ready() -> void:
	load_local_profile()

func load_local_profile() -> Dictionary:
	if local_profile_loaded:
		return local_profile_data

	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var raw_text := file.get_as_text()
			file.close()

			var json := JSON.new()
			var parse_result := json.parse(raw_text)
			if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
				local_profile_data = json.data
			else:
				local_profile_data = _build_default_profile()
		else:
			local_profile_data = _build_default_profile()
	else:
		local_profile_data = _build_default_profile()
		save_local_profile()

	local_profile_data = _ensure_profile_shape(local_profile_data)
	local_profile_loaded = true
	return local_profile_data

func save_local_profile() -> void:
	local_profile_data = _ensure_profile_shape(local_profile_data)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("HatAccountManager: Failed to open save file for writing: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(local_profile_data, "\t"))
	file.close()

func get_local_account_id() -> String:
	load_local_profile()
	return str(local_profile_data.get("account_id", DEFAULT_ACCOUNT_ID))

func get_local_username() -> String:
	load_local_profile()
	return str(local_profile_data.get("username", DEFAULT_USERNAME))

func get_local_hat_inventory() -> Dictionary:
	load_local_profile()
	_ensure_local_hat_profile_ready()
	return local_profile_data.get("hat_inventory", DEFAULT_HAT_INVENTORY.duplicate(true)).duplicate(true)

func set_local_hat_inventory(hat_inventory: Dictionary) -> void:
	load_local_profile()
	local_profile_data["hat_inventory"] = _sanitize_hat_inventory(hat_inventory)
	save_local_profile()

func _build_default_profile() -> Dictionary:
	return {
		"account_id": DEFAULT_ACCOUNT_ID,
		"username": DEFAULT_USERNAME,
		"hat_inventory": {
			"owned_items": [
				ItemDatabase.FALLBACK_HAT_ID
			],
			"equipped": {
				"head": ItemDatabase.FALLBACK_HAT_ID
			}
		}
	}

func _ensure_profile_shape(profile_data: Dictionary) -> Dictionary:
	var result: Dictionary = profile_data.duplicate(true)

	if not result.has("account_id"):
		result["account_id"] = DEFAULT_ACCOUNT_ID

	if not result.has("username"):
		result["username"] = DEFAULT_USERNAME

	if not result.has("hat_inventory"):
		result["hat_inventory"] = DEFAULT_HAT_INVENTORY.duplicate(true)
	else:
		result["hat_inventory"] = _sanitize_hat_inventory(result["hat_inventory"])

	return result

func _sanitize_hat_inventory(hat_inventory: Dictionary) -> Dictionary:
	var result := DEFAULT_HAT_INVENTORY.duplicate(true)

	var incoming_owned: Array = hat_inventory.get("owned_items", [])
	result["owned_items"] = []
	for item in incoming_owned:
		result["owned_items"].append(str(item))

	var incoming_equipped: Dictionary = hat_inventory.get("equipped", {})
	result["equipped"]["head"] = str(incoming_equipped.get("head", ""))

	return result

func _ensure_local_hat_profile_ready() -> void:
	load_local_profile()

	var hat_inventory: Dictionary = local_profile_data.get("hat_inventory", DEFAULT_HAT_INVENTORY.duplicate(true)).duplicate(true)
	hat_inventory = _sanitize_hat_inventory(hat_inventory)

	var owned_items: Array = hat_inventory.get("owned_items", [])
	var equipped: Dictionary = hat_inventory.get("equipped", {})
	var equipped_head: String = str(equipped.get("head", ""))

	var changed := false

	if owned_items.is_empty():
		hat_inventory["owned_items"] = [ItemDatabase.FALLBACK_HAT_ID]
		hat_inventory["equipped"] = { "head": ItemDatabase.FALLBACK_HAT_ID }
		changed = true
	elif equipped_head == "":
		hat_inventory["equipped"] = { "head": str(owned_items[0]) }
		changed = true

	local_profile_data["hat_inventory"] = hat_inventory

	if changed:
		save_local_profile()
