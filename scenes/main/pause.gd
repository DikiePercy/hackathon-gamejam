extends Node
@onready var pause_menu =$"../CanvasLayer/menupause"
@onready var _save_button: Button = $"../CanvasLayer/menupause/Panel/VBoxContainer/Button2"
@onready var _load_button: Button = $"../CanvasLayer/menupause/Panel/VBoxContainer/Button3"
@onready var _player: MainPerson = $"../Player"

const SAVE_FILE_PATH := "user://savegame.json"

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


func _on_menubutton_pressed() -> void:
	game_paused = !game_paused


func _on_save_button_pressed() -> void:
	var save_payload := {
		"game_manager": GameManager.to_save_dict(),
		"player": _collect_player_state(),
		"scene_path": get_tree().current_scene.scene_file_path
	}

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: cannot open save file")
		return

	file.store_string(JSON.stringify(save_payload))
	file.close()
	print("Save completed")


func _on_load_button_pressed() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		push_warning("Load failed: save file not found")
		return

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Load failed: cannot open save file")
		return

	var raw_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw_text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("Load failed: invalid save JSON")
		return

	var data: Dictionary = parsed
	if data.has("game_manager") and data["game_manager"] is Dictionary:
		GameManager.apply_save_dict(data["game_manager"])

	if data.has("player") and data["player"] is Dictionary:
		_apply_player_state(data["player"])

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
