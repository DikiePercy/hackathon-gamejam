# res://scenes/main/main.gd
extends Node2D

@onready var _player: MainPerson = $Player

func _ready() -> void:
	$"Train".go_trein.connect(_on_train_started)
	$"Train".stop_trein.connect(_stop_train_started)
	
func _on_player_died() -> void:
	get_tree().reload_current_scene()

func _on_train_started():
	$CanvasLayer/Button.hide()

	
func _stop_train_started(): 
	$CanvasLayer/Button.show()
