# res://scenes/characters/bullet.gd
extends Area2D
class_name Bullet

const SPEED := 650.0
var direction: Vector2 = Vector2.RIGHT

@onready var _timer: Timer = $LifetimeTimer

func _ready() -> void:
	_timer.wait_time = 2.5
	_timer.one_shot = true
	_timer.start()
	_timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	$Sprite.rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

func _on_body_entered(body: Node) -> void:
	if body is Person:
		body.take_damage(25)
	queue_free()
