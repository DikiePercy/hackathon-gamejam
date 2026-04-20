extends Node
@onready var pause_menu =$"../CanvasLayer/menupause"
@onready var _save_button: Button = $"../CanvasLayer/menupause/Panel/VBoxContainer/Button2"
@onready var _load_button: Button = $"../CanvasLayer/menupause/Panel/VBoxContainer/Button3"
@onready var _player: MainPerson = $"../Player"

const SAVE_DIR_PATH := "user://saves"

var game_paused: bool=false

func _ready() -> void:
	if _save_button != null and not _save_button.pressed.is_connected(_on_save_button_pressed):
		_save_button.pressed.connect(_on_save_button_pressed)
	if _load_button != null and not _load_button.pressed.is_connected(_on_load_button_pressed):
		_load_button.pressed.connect(_on_load_button_pressed)

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		game_paused = !game_paused
	if game_paused == true:
		get_tree().paused = true
		pause_menu.show()
	else:
		get_tree().paused = false
		pause_menu.hide()


func _on_button_pressed() -> void:
	game_paused = !game_paused


func _on_button_4_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/node_2d.tscn")


func _on_save_button_pressed() -> void:
	if GameManager.current_save_slot_id.is_empty():
		GameManager.current_save_slot_id = _new_slot_id()
	if not GameManager.autosave_current_state():
		push_warning("Save failed")
		return
	print("Save completed")


func _on_load_button_pressed() -> void:
	if not GameManager.load_latest_save_into_pending():
		push_warning("Load failed: no valid saves")
		return
	game_paused = false
	get_tree().paused = false
	var payload := GameManager.pending_load_data
	var scene_path := String(payload.get("scene_path", get_tree().current_scene.scene_file_path))
	get_tree().change_scene_to_file(scene_path)
	print("Load completed")


func _collect_player_state() -> Dictionary:
	if _player == null:
		return {}

	return {
		"position_x": _player.global_position.x,
		"position_y": _player.global_position.y,
		"health": _player.health,
		"max_health": _player.max_health
	}


func _apply_player_state(player_data: Dictionary) -> void:
	if _player == null:
		return

	var pos_x := float(player_data.get("position_x", _player.global_position.x))
	var pos_y := float(player_data.get("position_y", _player.global_position.y))
	_player.global_position = Vector2(pos_x, pos_y)

	_player.max_health = int(player_data.get("max_health", _player.max_health))
	_player.health = clampi(int(player_data.get("health", _player.health)), 0, _player.max_health)
	_player.health_changed.emit(_player.health)


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)


func _new_slot_id() -> String:
	return "save_%d" % int(Time.get_unix_time_from_system())


func _slot_path(slot_id: String) -> String:
	return SAVE_DIR_PATH.path_join("%s.json" % slot_id)
