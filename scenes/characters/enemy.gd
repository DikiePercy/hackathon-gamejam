extends Person

enum WeaponState {
	PATROL,
	SHOOTING,
	RELOADING,
	KNIFE
}

@export var _move_speed: float = 80.0
@export var _contact_damage: int = 10
@export var _knife_damage: int = 25
@export var _contact_damage_cooldown: float = 0.7
@export var _left_limit: float = -90.0
@export var _right_limit: float = 90.0
@export var bullet_scene: PackedScene
@export var shoot_cooldown: float = 1.5
@export var clip_size: int = 8
@export var reload_time: float = 1.8
@export var reload_count: int = 3
@export var detection_distance: float = 450.0
@export var shoot_distance: float = 320.0
@export var stop_distance: float = 120.0
@export var knife_speed_multiplier: float = 1.4

var _direction: int = 1
var _damage_timer: float = 0.0
var _shoot_timer: float = 0.0
var _reload_timer: float = 0.0
var _ammo_in_clip: int = clip_size
var _reloads_left: int = reload_count
var _weapon_state: WeaponState = WeaponState.PATROL
var _player_in_contact: MainPerson = null
var _player: MainPerson = null

@onready var _sprite: AnimatedSprite2D = $Visual


func _ready() -> void:
	_player = _find_player()
	_ammo_in_clip = clip_size
	_reloads_left = reload_count
	_weapon_state = WeaponState.PATROL


func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		_player = _find_player()

	var player_dist: float = INF
	var player_visible: bool = false
	if _player != null:
		player_dist = global_position.distance_to(_player.global_position)
		player_visible = player_dist <= detection_distance

	if _weapon_state == WeaponState.RELOADING:
		_reload_timer = maxf(_reload_timer - delta, 0.0)
		velocity.x = 0.0
		if _reload_timer <= 0.0:
			_finish_reload()
	elif _weapon_state == WeaponState.KNIFE:
		if player_visible:
			_update_direction_toward(_player.global_position)
			velocity.x = _direction * _move_speed * knife_speed_multiplier
		else:
			velocity.x = _direction * _move_speed
	else:
		if player_visible:
			_update_direction_toward(_player.global_position)
			if player_dist > stop_distance:
				velocity.x = _direction * _move_speed
			else:
				velocity.x = 0.0

			if _weapon_state == WeaponState.SHOOTING and player_dist <= shoot_distance:
				_try_shoot_at(_player)
			elif _weapon_state == WeaponState.PATROL and player_dist <= shoot_distance and _ammo_in_clip > 0:
				_weapon_state = WeaponState.SHOOTING

			if _weapon_state == WeaponState.SHOOTING and _ammo_in_clip <= 0:
				if _reloads_left > 0:
					_start_reload()
				else:
					_weapon_state = WeaponState.KNIFE
		else:
			if not player_visible:
				if global_position.x <= _left_limit_global():
					_direction = 1
				elif global_position.x >= _right_limit_global():
					_direction = -1
				velocity.x = _direction * _move_speed

	move_and_slide()

	if _damage_timer > 0.0:
		_damage_timer = maxf(_damage_timer - delta, 0.0)

	if _shoot_timer > 0.0:
		_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	if _player_in_contact != null and _damage_timer <= 0.0:
		_player_in_contact.take_damage(_knife_damage if _weapon_state == WeaponState.KNIFE else _contact_damage)
		_damage_timer = _contact_damage_cooldown


func _left_limit_global() -> float:
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


func _find_player() -> MainPerson:
	var scene = get_tree().current_scene
	if scene != null:
		var player = scene.get_node_or_null("Player")
		if player is MainPerson:
			return player as MainPerson
		return scene.find_node("Player", true, false) as MainPerson
	return null


func _update_direction_toward(target_position: Vector2) -> void:
	_direction = 1 if target_position.x > global_position.x else -1
	if _sprite != null:
		_sprite.scale.x = 1.0 if _direction > 0 else -1.0


func _try_shoot_at(target: MainPerson) -> void:
	if _weapon_state == WeaponState.KNIFE:
		return

	if _shoot_timer > 0.0:
		return

	if _ammo_in_clip <= 0:
		if _reloads_left > 0:
			_start_reload()
		else:
			_weapon_state = WeaponState.KNIFE
		return

	_shoot_at_target(target)
	_ammo_in_clip -= 1
	_shoot_timer = shoot_cooldown

	if _ammo_in_clip <= 0:
		if _reloads_left > 0:
			_start_reload()
		else:
			_weapon_state = WeaponState.KNIFE


func _start_reload() -> void:
	_weapon_state = WeaponState.RELOADING
	_reload_timer = reload_time
	print("Enemy: перезарядка... осталось перезарядок ", _reloads_left)


func _finish_reload() -> void:
	if _reloads_left > 0:
		_reloads_left -= 1
		_ammo_in_clip = clip_size
		_weapon_state = WeaponState.SHOOTING
		print("Enemy: перезаряжен. Патронов в обойме: ", _ammo_in_clip, ", перезарядок осталось: ", _reloads_left)
	else:
		_weapon_state = WeaponState.KNIFE
		print("Enemy: патроны закончились, берёт нож")


func _shoot_at_target(target: MainPerson) -> void:
	if not bullet_scene:
		push_warning("Enemy: назначь bullet_scene в инспекторе!")
		return

	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var shoot_dir = (target.global_position - global_position).normalized()
	bullet.direction = shoot_dir
	bullet.global_position = global_position + shoot_dir * 24.0
