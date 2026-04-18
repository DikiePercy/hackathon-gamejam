# res://classes/enemy.gd
extends Person
class_name Enemy

@export var _move_speed: float = 80.0
@export var _contact_damage: int = 10
@export var _contact_damage_cooldown: float = 0.7
@export var _left_limit: float = -90.0
@export var _right_limit: float = 90.0

var _direction: int = 1
var _damage_timer: float = 0.0
var _player_in_contact: MainPerson = null


func _physics_process(delta: float) -> void:
	# Простое патрулирование в пределах вагона
	velocity.x = _direction * _move_speed
	move_and_slide()

	if global_position.x <= _left_limit_global():
		_direction = 1
	elif global_position.x >= _right_limit_global():
		_direction = -1

	# Урон игроку при контакте с кулдауном
	if _damage_timer > 0.0:
		_damage_timer -= delta

	if _player_in_contact != null and _damage_timer <= 0.0:
		_player_in_contact.take_damage(_contact_damage)
		_damage_timer = _contact_damage_cooldown


func _left_limit_global() -> float:
	# Границы патруля считаем от родителя (обычно вагон)
	if get_parent() != null:
		return get_parent().global_position.x + _left_limit
	return global_position.x - 100.0


func _right_limit_global() -> float:
	if get_parent() != null:
		return get_parent().global_position.x + _right_limit
	return global_position.x + 100.0


func _on_hitbox_body_entered(body: Node) -> void:
	if body is MainPerson:
		_player_in_contact = body as MainPerson


func _on_hitbox_body_exited(body: Node) -> void:
	if body == _player_in_contact:
		_player_in_contact = null
