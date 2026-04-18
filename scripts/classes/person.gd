class_name Person
extends CharacterBody2D

@export var max_health: int = 100
var health: int = 100   # не используем max_health здесь — иначе будет 0

signal health_changed(new_health: int)
signal died

func _ready() -> void:
	health = max_health   # теперь возьмёт правильное значение из инспектора

func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	health_changed.emit(health)
	if health == 0:
		die()

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	health_changed.emit(health)

func die() -> void:
	died.emit()
	queue_free()
