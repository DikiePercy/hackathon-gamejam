# res://scenes/main/main.gd
extends Node2D

@onready var _player: MainPerson = $Player

func _ready() -> void:
	_apply_pending_load()
	if _player != null:
		_player.died.connect(_on_player_died)

func _apply_pending_load() -> void:
	if GameManager.pending_load_data.is_empty():
		return

	var data := GameManager.pending_load_data
	GameManager.pending_load_data = {}

	if data.has("game_manager") and data["game_manager"] is Dictionary:
		GameManager.apply_save_dict(data["game_manager"])

	if _player != null and data.has("player") and data["player"] is Dictionary:
		var player_data: Dictionary = data["player"]
		var pos_x := float(player_data.get("position_x", _player.global_position.x))
		var pos_y := float(player_data.get("position_y", _player.global_position.y))
		_player.global_position = Vector2(pos_x, pos_y)

		_player.max_health = int(player_data.get("max_health", _player.max_health))
		_player.health = clampi(int(player_data.get("health", _player.health)), 0, _player.max_health)
		_player.health_changed.emit(_player.health)
func _on_player_died() -> void:
	get_tree().reload_current_scene()
	
