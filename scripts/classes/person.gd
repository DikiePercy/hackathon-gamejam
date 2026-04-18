class_name Person
extends CharacterBody2D

var health := 100

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	pass
