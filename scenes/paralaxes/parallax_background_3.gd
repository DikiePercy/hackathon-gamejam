extends ParallaxBackground

@export var speed: float = 250.0          # скорость "поезда"
var accumulated_offset: float = 0.0

func _process(delta: float) -> void:
	accumulated_offset -= speed * delta
	
	scroll_base_offset.x = accumulated_offset
	
