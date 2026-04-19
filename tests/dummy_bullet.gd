extends Area2D

var direction: Vector2 = Vector2.RIGHT
var damage: int = 0

func _ready() -> void:
	queue_free()
