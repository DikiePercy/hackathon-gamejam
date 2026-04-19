extends Node2D


func _process(delta):
	print(position.x)
	
	if position.x != 0 :
		position.x = 0
	elif position.x > 450:
		position.x = 450
