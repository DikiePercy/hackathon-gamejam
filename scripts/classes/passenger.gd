class_name Passenger
extends Person

@export var seat_offset: Vector2 = Vector2(0.0, -18.0)


func _ready() -> void:
	super._ready()
	add_to_group("passenger")
	velocity = Vector2.ZERO


func sit_at_global(global_seat_position: Vector2) -> void:
	global_position = global_seat_position + seat_offset
	velocity = Vector2.ZERO
