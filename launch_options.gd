extends Node

const DEFAULT_SERVER_IP := "127.0.0.1"
const DEFAULT_SERVER_PORT := 8910

var raw_args: PackedStringArray = PackedStringArray()
var options: Dictionary = {}

func _ready() -> void:
	raw_args = OS.get_cmdline_user_args()
	_parse_args(raw_args)

func _parse_args(args: PackedStringArray) -> void:
	options.clear()

	for raw_arg in args:
		var arg := str(raw_arg).strip_edges()
		if arg == "":
			continue

		if arg.begins_with("--"):
			arg = arg.substr(2)

		var key := arg
		var value: Variant = true

		var separator_index := arg.find("=")
		if separator_index >= 0:
			key = arg.substr(0, separator_index)
			value = arg.substr(separator_index + 1)

		key = String(key).strip_edges().to_lower()
		if key != "":
			options[key] = value

func has_flag(flag_name: String) -> bool:
	return bool(options.get(flag_name.to_lower(), false))

func get_string(option_name: String, fallback: String = "") -> String:
	var value: Variant = options.get(option_name.to_lower(), fallback)
	return str(value)

func get_int(option_name: String, fallback: int) -> int:
	var value_text := get_string(option_name, str(fallback))
	if value_text.is_valid_int():
		return int(value_text)
	return fallback

func get_float(option_name: String, fallback: float) -> float:
	var value_text := get_string(option_name, str(fallback))
	if value_text.is_valid_float():
		return float(value_text)
	return fallback

func should_auto_advance_title() -> bool:
	if has_flag("auto-advance-title"):
		return true

	if should_smoke_exit_on_scene("title"):
		return false

	return has_flag("smoke") or has_flag("smoke-combat")

func get_player_name_override() -> String:
	return get_string("player-name", "")

func get_server_ip(default_value: String = DEFAULT_SERVER_IP) -> String:
	return get_string("server-ip", default_value)

func get_server_port(default_value: int = DEFAULT_SERVER_PORT) -> int:
	return get_int("server-port", default_value)

func get_menu_action() -> String:
	var action := get_string("menu-action", "")
	if action == "":
		if has_flag("auto-join") or has_flag("smoke") or has_flag("smoke-combat"):
			action = "join"
		elif has_flag("auto-host"):
			action = "host"
	return action.to_lower()

func get_smoke_target_scene() -> String:
	var target := get_string("smoke-exit-scene", "")
	if target == "" and has_flag("smoke"):
		target = "round_over"
	return target.to_lower()

func get_smoke_exit_delay() -> float:
	return max(get_float("smoke-exit-delay", 2.0), 0.0)

func should_smoke_exit_on_scene(scene_key: String) -> bool:
	var target := get_smoke_target_scene()
	return target != "" and target == scene_key.to_lower()

func get_test_round_winner() -> String:
	return get_string("test-round-winner", "").to_lower()

func get_test_round_end_delay() -> float:
	return max(get_float("test-round-end-delay", 1.0), 0.0)

func get_expected_local_result() -> String:
	return get_string("expected-local-result", "").replace("_", " ").to_upper()

func should_skip_match_intro() -> bool:
	return has_flag("test-skip-intro") or has_flag("smoke-combat")
