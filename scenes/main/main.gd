# res://scenes/main/main.gd
extends Node2D

@onready var _player: MainPerson = $Player

func _ready() -> void:
	if _player != null:
		_player.died.connect(_on_player_died)
func _on_player_died() -> void:
	get_tree().reload_current_scene()
	
