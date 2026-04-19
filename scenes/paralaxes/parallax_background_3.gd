extends ParallaxBackground

@export var speed: float = GameManager.train_speed          # скорость "поезда"
var accumulated_offset: float = 0.0

func _process(delta: float) -> void:
	speed = GameManager.train_speed 
	accumulated_offset -= speed * delta
	
	scroll_base_offset.x = accumulated_offset
	
