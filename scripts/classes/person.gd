class_name Person
extends CharacterBody2D

@export var max_health: int = 100
var health: int = 100 

var death_y = 1000

signal health_changed(new_health: int)
signal died

func _process(delta: float) -> void:
	var position = global_position
	var x = global_position.x
	var y = global_position.y
	if global_position.y > death_y:
		die()

func _ready() -> void:
	health = max_health


func _physics_process(delta: float) -> void:
	if _knockback_timer > 0.0:
		_knockback_timer -= delta

## Применяет импульс отброса.
## [param force] — вектор скорости в глобальных координатах,
## например Vector2(450, -200) (вправо и вверх).
func apply_knockback(force: Vector2) -> void:
	velocity = force
	_knockback_timer = KNOCKBACK_DURATION

## Возвращает true, пока персонаж находится в состоянии отброса.
func is_knocked_back() -> bool:
	return _knockback_timer > 0.0

# ─────────────────────────────────────────────────────────────────────────────

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
