extends Node
@onready var pause_menu =$"../CanvasLayer/menupause"
var game_paused: bool=false
func _process(delta):
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
