extends ParallaxBackground

var speeed=100

func _process(delta):
	scroll_offset.x -= speeed * delta
	
