# res://scenes/menu/node_2d.gd
extends Node2D

@onready var _menu_music: AudioStreamPlayer = $MenuMusic
var _menu_music_restart_timer := 60.0

func _ready() -> void:
	_menu_music.play()
	_menu_music.finished.connect(_on_menu_music_finished)

func _process(delta: float) -> void:
	_menu_music_restart_timer -= delta
	if _menu_music_restart_timer <= 0.0:
		_menu_music_restart_timer += 60.0
		if _menu_music != null:
			_menu_music.play()

func _on_menu_music_finished() -> void:
	_menu_music.play()

func _on_quit_pressed():
	get_tree().quit()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_depot_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/depot/depot.tscn")
