# res://scenes/menu/node_2d.gd
extends Node2D

func _on_quit_pressed():
	get_tree().quit()

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func _on_depot_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/depot/depot.tscn")
