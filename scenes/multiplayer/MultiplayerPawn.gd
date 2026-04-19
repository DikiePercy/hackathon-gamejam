extends CharacterBody2D
class_name MultiplayerPawn

signal shot_fired(origin: Vector2, direction: Vector2)

const SPEED := 220.0
const GRAVITY := 1000.0
const JUMP_VELOCITY := -320.0
const SHOOT_COOLDOWN := 0.25

@export var bullet_scene: PackedScene = preload("res://scenes/characters/Bullet.tscn")
@export var player_color: Color = Color(0.9, 0.9, 1.0)

var is_local: bool = false
var aim_direction: Vector2 = Vector2.RIGHT
var facing_right: bool = true
var _shoot_timer: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _gun_point: Marker2D = $GunPoint

func _ready() -> void:
	if _sprite != null:
		_sprite.modulate = player_color
	_update_gun_point()

func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	velocity.y += GRAVITY * delta
	if is_local:
		_process_input(delta)
	else:
		velocity.x = 0.0
	move_and_slide()

func _process_input(_delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED
	if dir != 0.0:
		facing_right = dir > 0.0
		_sprite.flip_h = not facing_right
		_update_gun_point()
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	_update_aim()
	if Input.is_action_just_pressed("shoot") and _shoot_timer == 0.0:
		_shoot_timer = SHOOT_COOLDOWN
		emit_signal("shot_fired", _gun_point.global_position, aim_direction)

func _update_aim() -> void:
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - _gun_point.global_position
	if to_mouse.length() <= 0.001:
		return
	aim_direction = to_mouse.normalized()
	facing_right = aim_direction.x >= 0.0
	_sprite.flip_h = not facing_right
	_update_gun_point()

func _update_gun_point() -> void:
	if _gun_point == null:
		return
	_gun_point.position.x = 18.0 if facing_right else -18.0

func set_remote_state(new_position: Vector2, facing: bool, aim_dir: Vector2) -> void:
	global_position = new_position
	facing_right = facing
	aim_direction = aim_dir
	if _sprite != null:
		_sprite.flip_h = not facing
	_update_gun_point()

func get_network_state() -> Dictionary:
	return {
		"position": global_position,
		"facing_right": facing_right,
		"aim_direction": aim_direction
	}
