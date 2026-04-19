# res://scenes/characters/bullet.gd
extends Area2D
class_name Bullet

const SPEED := 650.0
const TRACER_LENGTH := 18.0
var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 25
@export var owner_peer_id: int = 0

@onready var _timer: Timer = $LifetimeTimer
@onready var _sprite: ColorRect = $Sprite
@onready var _tracer: Line2D = get_node_or_null("Tracer")

func _ready() -> void:
	_timer.wait_time = 2.5
	_timer.one_shot = true
	_timer.start()
	_timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_update_visuals()

func _update_visuals() -> void:
	if direction.length_squared() <= 0.000001:
		return

	var dir := direction.normalized()
	if _sprite != null:
		_sprite.rotation = dir.angle()

	if _tracer != null:
		_tracer.clear_points()
		_tracer.add_point(Vector2.ZERO)
		_tracer.add_point(-dir * TRACER_LENGTH)

func _on_body_entered(body: Node) -> void:
	if body is Person:
		body.take_damage(damage)
	queue_free()
