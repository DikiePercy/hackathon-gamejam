extends Camera2D

func _process(delta):
	if position.x < -2000 :
		position.x = -2000
	elif position.x > 0:
		position.x = 0
