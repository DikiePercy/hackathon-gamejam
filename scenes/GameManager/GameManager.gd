extends Node

const DEFAULT_TOTAL_GOLD := 100
const DEFAULT_HAS_SHOTGUN := false
const DEFAULT_TOTAL_P := 100
const DEFAULT_TRAIN_SPEED := 250
const DEFAULT_TRAIN_LEVEL := 1
const DEFAULT_TRAIN_INTEGRITY_MAX := 300
const DEFAULT_MISSION_TARGET_DISTANCE := 10000
const DEFAULT_MISSION_TIME_LIMIT := 180.0
const DEFAULT_REWARD_BASE := 220
const DEFAULT_REWARD_PER_PASSENGER := 40
const DEFAULT_FAIL_PENALTY := 60
const SAVE_DIR_PATH := "user://saves"
const AUTOSAVE_SLOT_ID := "autosave"
const DEFAULT_TRAIN_DATA := [
	[1, 5, 1],
	[1, 3, 2]
]

var total_gold = 5000
var has_shotgun: bool = false
var total_p = 100
var train_speed = 0
var train_integrity_max: int = DEFAULT_TRAIN_INTEGRITY_MAX
var train_integrity_current: int = DEFAULT_TRAIN_INTEGRITY_MAX
var mission_target_distance: float = DEFAULT_MISSION_TARGET_DISTANCE
var mission_time_limit: float = DEFAULT_MISSION_TIME_LIMIT
var mission_reward_base: int = DEFAULT_REWARD_BASE
var mission_reward_per_passenger: int = DEFAULT_REWARD_PER_PASSENGER
var mission_fail_penalty: int = DEFAULT_FAIL_PENALTY
var pending_mission_reward: int = 0
var last_mission_result: Dictionary = {}
var station_pos = 0

# Структура: [ [уровень, люди, hp], [уровень, люди, hp] ]
var train_data: Array = [
	[1, 5, 1], # Первый вагон
	[1, 3, 2]  # Второй вагон
]

var train_level = 1 
var current_save_slot_id: String = ""
var pending_load_data: Dictionary = {}
var _is_quitting: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _is_quitting:
		_is_quitting = true
		autosave_current_state()
		get_tree().quit()

func reset_to_defaults() -> void:
	total_gold = DEFAULT_TOTAL_GOLD
	has_shotgun = DEFAULT_HAS_SHOTGUN
	total_p = DEFAULT_TOTAL_P
	train_speed = 0
	train_level = DEFAULT_TRAIN_LEVEL
	train_data = DEFAULT_TRAIN_DATA.duplicate(true)
	train_integrity_max = DEFAULT_TRAIN_INTEGRITY_MAX
	train_integrity_current = train_integrity_max
	mission_target_distance = DEFAULT_MISSION_TARGET_DISTANCE
	mission_time_limit = DEFAULT_MISSION_TIME_LIMIT
	mission_reward_base = DEFAULT_REWARD_BASE
	mission_reward_per_passenger = DEFAULT_REWARD_PER_PASSENGER
	mission_fail_penalty = DEFAULT_FAIL_PENALTY
	pending_mission_reward = 0
	last_mission_result = {}

func to_save_dict() -> Dictionary:
	return {
		"total_gold": total_gold,
		"has_shotgun": has_shotgun,
		"total_p": total_p,
		"train_speed": train_speed,
		"train_level": train_level,
		"train_data": train_data.duplicate(true),
		"train_integrity_max": train_integrity_max,
		"train_integrity_current": train_integrity_current,
		"mission_target_distance": mission_target_distance,
		"mission_time_limit": mission_time_limit,
		"mission_reward_base": mission_reward_base,
		"mission_reward_per_passenger": mission_reward_per_passenger,
		"mission_fail_penalty": mission_fail_penalty,
		"pending_mission_reward": pending_mission_reward,
		"last_mission_result": last_mission_result.duplicate(true)
	}

func apply_save_dict(data: Dictionary) -> void:
	total_gold = int(data.get("total_gold", total_gold))
	has_shotgun = bool(data.get("has_shotgun", has_shotgun))
	total_p = int(data.get("total_p", total_p))
	train_speed = int(data.get("train_speed", train_speed))
	train_level = int(data.get("train_level", train_level))
	train_integrity_max = int(data.get("train_integrity_max", train_integrity_max))
	train_integrity_current = int(data.get("train_integrity_current", train_integrity_current))
	mission_target_distance = float(data.get("mission_target_distance", mission_target_distance))
	mission_time_limit = float(data.get("mission_time_limit", mission_time_limit))
	mission_reward_base = int(data.get("mission_reward_base", mission_reward_base))
	mission_reward_per_passenger = int(data.get("mission_reward_per_passenger", mission_reward_per_passenger))
	mission_fail_penalty = int(data.get("mission_fail_penalty", mission_fail_penalty))
	pending_mission_reward = int(data.get("pending_mission_reward", pending_mission_reward))
	var loaded_result = data.get("last_mission_result", {})
	if loaded_result is Dictionary:
		last_mission_result = (loaded_result as Dictionary).duplicate(true)

	var loaded_train_data = data.get("train_data", train_data)
	if loaded_train_data is Array and loaded_train_data.size() > 0:
		train_data = loaded_train_data.duplicate(true)

	_clamp_integrity_values()

func begin_mission_run() -> void:
	train_integrity_current = train_integrity_max
	pending_mission_reward = 0

func apply_train_damage(amount: int) -> int:
	train_integrity_current = clampi(train_integrity_current - maxi(amount, 0), 0, train_integrity_max)
	return train_integrity_current

func apply_mission_result(success: bool, passengers_alive: int, time_left: float, distance_ratio: float) -> Dictionary:
	var clamped_passengers: int = maxi(passengers_alive, 0)
	var clamped_ratio: float = clampf(distance_ratio, 0.0, 1.5)
	var reward: int = 0

	if success:
		reward = mission_reward_base + clamped_passengers * mission_reward_per_passenger + int(round(80.0 * clamped_ratio))
		total_gold += reward
	else:
		reward = -mission_fail_penalty
		total_gold = maxi(total_gold + reward, 0)

	pending_mission_reward = reward
	last_mission_result = {
		"success": success,
		"reward": reward,
		"passengers_alive": clamped_passengers,
		"time_left": maxf(time_left, 0.0),
		"distance_ratio": clamped_ratio,
		"train_integrity": train_integrity_current,
		"saved_at_unix": int(Time.get_unix_time_from_system())
	}
	return last_mission_result.duplicate(true)

func autosave_current_state() -> bool:
	var payload := _build_save_payload()
	if payload.is_empty():
		return false

	var target_slot := current_save_slot_id if not current_save_slot_id.is_empty() else AUTOSAVE_SLOT_ID
	if not _write_slot(target_slot, payload):
		return false

	# Keep a dedicated rolling autosave as backup.
	if target_slot != AUTOSAVE_SLOT_ID:
		_write_slot(AUTOSAVE_SLOT_ID, payload)

	return true

func _build_save_payload() -> Dictionary:
	var scene := get_tree().current_scene
	var scene_path := ""
	if scene != null:
		scene_path = scene.scene_file_path

	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := Time.get_datetime_string_from_system().replace("T", " ")

	var slot_id := _resolved_target_slot_id()
	return {
		"meta": {
			"slot_id": slot_id,
			"saved_at_text": now_text,
			"saved_at_unix": now_unix
		},
		"game_manager": to_save_dict(),
		"player": _collect_player_state(),
		"scene_path": scene_path
	}

func _collect_player_state() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return {}

	var player := scene.get_node_or_null("Player")
	if player == null:
		player = scene.find_child("Player", true, false)
	if player == null:
		return {}

	var health = player.get("health")
	var max_health = player.get("max_health")
	return {
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"health": int(health) if health != null else 100,
		"max_health": int(max_health) if max_health != null else 100
	}

func _write_slot(slot_id: String, payload: Dictionary) -> bool:
	if slot_id.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func _slot_path(slot_id: String) -> String:
	return SAVE_DIR_PATH.path_join("%s.json" % slot_id)

func get_latest_save_payload() -> Dictionary:
	# 1) Prefer currently active slot if it exists.
	if not current_save_slot_id.is_empty():
		var active_payload := _read_slot_payload(current_save_slot_id)
		if not active_payload.is_empty():
			return active_payload

	# 2) Fallback to rolling autosave.
	var autosave_payload := _read_slot_payload(AUTOSAVE_SLOT_ID)
	if not autosave_payload.is_empty():
		return autosave_payload

	# 3) Else pick the newest by saved_at_unix.
	var newest_payload: Dictionary = {}
	var newest_time: int = -1
	var dir := DirAccess.open(SAVE_DIR_PATH)
	if dir == null:
		return {}

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue

		var slot_id := file_name.trim_suffix(".json")
		var payload := _read_slot_payload(slot_id)
		if payload.is_empty():
			continue

		var meta: Dictionary = payload.get("meta", {}) as Dictionary
		var save_time: int = int(meta.get("saved_at_unix", 0))
		if save_time > newest_time:
			newest_time = save_time
			newest_payload = payload

	return newest_payload

func load_latest_save_into_pending() -> bool:
	var payload := get_latest_save_payload()
	if payload.is_empty():
		return false

	var meta: Dictionary = payload.get("meta", {}) as Dictionary
	if not meta.is_empty():
		current_save_slot_id = String(meta.get("slot_id", current_save_slot_id))

	pending_load_data = payload
	return true

func _read_slot_payload(slot_id: String) -> Dictionary:
	if slot_id.is_empty():
		return {}

	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not (parsed is Dictionary):
		return {}

	return parsed as Dictionary

func _resolved_target_slot_id() -> String:
	return current_save_slot_id if not current_save_slot_id.is_empty() else AUTOSAVE_SLOT_ID

func _clamp_integrity_values() -> void:
	train_integrity_max = maxi(train_integrity_max, 1)
	train_integrity_current = clampi(train_integrity_current, 0, train_integrity_max)
