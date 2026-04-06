extends Control

@export var next_scene_path: String = "res://main_menu.tscn"

@onready var play_button: Button = $MenuRoot/Play
@onready var name_input: LineEdit = $NameInput

const PLAYER_NAME_SAVE_PATH := "user://player_name.save"

func _ready() -> void:
	print("TITLE READY")

	if play_button != null:
		play_button.disabled = false
		play_button.mouse_filter = Control.MOUSE_FILTER_STOP

		if not play_button.pressed.is_connected(_on_play_pressed):
			play_button.pressed.connect(_on_play_pressed)

		if not play_button.mouse_entered.is_connected(_on_play_hovered):
			play_button.mouse_entered.connect(_on_play_hovered)

		if not play_button.mouse_exited.is_connected(_on_play_unhovered):
			play_button.mouse_exited.connect(_on_play_unhovered)

	if name_input != null:
		name_input.max_length = 16
		name_input.placeholder_text = "ENTER NAME"
		_load_saved_name()

func _load_saved_name() -> void:
	if not FileAccess.file_exists(PLAYER_NAME_SAVE_PATH):
		return

	var file := FileAccess.open(PLAYER_NAME_SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var saved_name := file.get_as_text().strip_edges()
	file.close()

	name_input.text = saved_name
	PlayerNameManager.set_player_name_value(saved_name)

func _save_name(value: String) -> void:
	var file := FileAccess.open(PLAYER_NAME_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(value)
	file.close()

func _on_play_pressed() -> void:
	var input_name := ""
	if name_input != null:
		input_name = name_input.text.strip_edges()

	PlayerNameManager.set_player_name_value(input_name)
	_save_name(PlayerNameManager.get_player_name_value())

	print("TITLE | NAME CONFIRMED: ", PlayerNameManager.get_player_name_value())
	print("TITLE | GOING TO MAIN MENU")

	var err := get_tree().change_scene_to_file(next_scene_path)
	if err != OK:
		push_error("TitleScreen | Failed to load next scene: %s" % next_scene_path)

func _on_play_hovered() -> void:
	print("PLAY HOVERED")

func _on_play_unhovered() -> void:
	print("PLAY UNHOVERED")
