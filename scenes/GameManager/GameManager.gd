extends Node

const DEFAULT_TOTAL_GOLD := 5000
const DEFAULT_HAS_SHOTGUN := false
const DEFAULT_TOTAL_P := 100
const DEFAULT_TRAIN_SPEED := 250
const DEFAULT_TRAIN_LEVEL := 1
const SAVE_DIR_PATH := "user://saves"
const AUTOSAVE_SLOT_ID := "autosave"
const DEFAULT_TRAIN_DATA := [
	[1, 5, 1],
	[1, 3, 2]
]

var total_gold = 5000
var has_shotgun: bool = false
var total_p = 100
var train_speed = 250

# Структура: [ [уровень, люди, hp], [уровень, люди, hp] ]
var train_data = [
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
	train_speed = DEFAULT_TRAIN_SPEED
	train_level = DEFAULT_TRAIN_LEVEL
	train_data = DEFAULT_TRAIN_DATA.duplicate(true)

func to_save_dict() -> Dictionary:
	return {
		"total_gold": total_gold,
		"has_shotgun": has_shotgun,
		"total_p": total_p,
		"train_speed": train_speed,
		"train_level": train_level,
		"train_data": train_data.duplicate(true)
	}

func apply_save_dict(data: Dictionary) -> void:
	total_gold = int(data.get("total_gold", total_gold))
	has_shotgun = bool(data.get("has_shotgun", has_shotgun))
	total_p = int(data.get("total_p", total_p))
	train_speed = int(data.get("train_speed", train_speed))
	train_level = int(data.get("train_level", train_level))

	var loaded_train_data = data.get("train_data", train_data)
	if loaded_train_data is Array and loaded_train_data.size() > 0:
		train_data = loaded_train_data.duplicate(true)

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

	var slot_id := current_save_slot_id if not current_save_slot_id.is_empty() else AUTOSAVE_SLOT_ID
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
	DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func _slot_path(slot_id: String) -> String:
	return SAVE_DIR_PATH.path_join("%s.json" % slot_id)
