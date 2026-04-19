extends ParallaxBackground
var speed = GameManager.train_speed

func _process(delta):
	scroll_offset.x -= speed * delta
	
