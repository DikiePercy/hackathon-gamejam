extends Person

enum WeaponState {
	PATROL,
	SHOOTING,
	RELOADING,
	KNIFE
}

enum RaidState {
	APPROACH_TRAIN,
	BOARD_TRAIN,
	ATTACK
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
@export var gravity: float = 1000.0
@export var jump_velocity: float = -340.0
@export var jump_cooldown: float = 0.9
@export var jump_trigger_height: float = 30.0
@export var jump_trigger_distance: float = 150.0
@export var knife_speed_multiplier: float = 1.4
@export var board_speed_multiplier: float = 1.2
@export var board_reach_threshold: float = 10.0
@export var approach_reach_threshold: float = 24.0

var _direction: int = 1
var _damage_timer: float = 0.0
var _shoot_timer: float = 0.0
var _reload_timer: float = 0.0
var _ammo_in_clip: int = clip_size
var _reloads_left: int = reload_count
var _weapon_state: WeaponState = WeaponState.PATROL
var _raid_state: RaidState = RaidState.APPROACH_TRAIN
var _target_in_contact: Person = null
var _player: MainPerson = null
var _train_node: Node2D = null
var _boarding_target: Vector2 = Vector2.ZERO
var _patrol_anchor_x: float = 0.0
var _shoot_anim_timer: float = 0.0
var _jump_timer: float = 0.0

var dst_shoot_sound: AudioStream = preload("res://assets/sounds/128300__xenonn__layered-gunshot-4.wav")

@onready var _sprite: AnimatedSprite2D = $Visual
@onready var _audio: AudioStreamPlayer = null

var _sprite_base_scale_x: float = 1.0

func _ready() -> void:
	_player = _find_player()
	_ammo_in_clip = clip_size
	_reloads_left = reload_count
	_weapon_state = WeaponState.PATROL
	if _sprite != null:
		_sprite_base_scale_x = absf(_sprite.scale.x)
		if _sprite_base_scale_x <= 0.001:
			_sprite_base_scale_x = 1.0
	if _boarding_target == Vector2.ZERO:
		_boarding_target = global_position + Vector2(100.0, 0.0)
	_patrol_anchor_x = _boarding_target.x
	if has_node("Audio"):
		_audio = $Audio
	else:
		_audio = AudioStreamPlayer.new()
		_audio.name = "Audio"
		add_child(_audio)
	_audio.bus = "Master"
	_audio.volume_db = 0.0
	_audio.stream = dst_shoot_sound

func setup_for_train_raid(train_node: Node2D, boarding_target: Vector2) -> void:
	_train_node = train_node
	_boarding_target = boarding_target
	_patrol_anchor_x = boarding_target.x
	_raid_state = RaidState.APPROACH_TRAIN

func _physics_process(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		_player = _find_player()

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if _raid_state == RaidState.APPROACH_TRAIN:
		_process_approach_train()
	elif _raid_state == RaidState.BOARD_TRAIN:
		_process_board_train()
	else:
		_process_attack_state(delta)

	move_and_slide()

	if _damage_timer > 0.0:
		_damage_timer = maxf(_damage_timer - delta, 0.0)
	if _shoot_timer > 0.0:
		_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer = maxf(_shoot_anim_timer - delta, 0.0)
	if _jump_timer > 0.0:
		_jump_timer = maxf(_jump_timer - delta, 0.0)

	_update_visual_animation()

	_apply_contact_damage()

func _process_approach_train() -> void:
	_update_direction_toward(_boarding_target)
	velocity.x = _direction * _move_speed
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
	if absf(global_position.x - _boarding_target.x) <= approach_reach_threshold:
		_raid_state = RaidState.BOARD_TRAIN

func _process_board_train() -> void:
	# Let enemies fire during boarding if player is already in range.
	if _player != null and _player.is_inside_tree():
		var player_dist_x := absf(_player.global_position.x - global_position.x)
		if player_dist_x <= shoot_distance:
			if _weapon_state == WeaponState.PATROL and _ammo_in_clip > 0:
				_weapon_state = WeaponState.SHOOTING
			if _weapon_state == WeaponState.SHOOTING:
				_try_shoot_at(_player)

	var to_target := _boarding_target - global_position
	if to_target.length() <= board_reach_threshold:
		velocity = Vector2.ZERO
		_raid_state = RaidState.ATTACK
		return

	var move_dir := to_target.normalized()
	velocity = move_dir * _move_speed * board_speed_multiplier
	_direction = 1 if move_dir.x >= 0.0 else -1
	_apply_visual_direction()

func _process_attack_state(delta: float) -> void:
	var target := _pick_attack_target()
	var target_visible := target != null
	var target_dist_x := INF

	if target_visible:
		target_dist_x = absf(target.global_position.x - global_position.x)
		_update_direction_toward(target.global_position)

	if _weapon_state == WeaponState.RELOADING:
		_reload_timer = maxf(_reload_timer - delta, 0.0)
		velocity.x = 0.0
		if is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	if _weapon_state == WeaponState.KNIFE:
		if target_visible:
			_try_jump_toward(target)
			velocity.x = _direction * _move_speed * knife_speed_multiplier
		else:
			_patrol_near_train()
		if is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0
		return

	if target_visible:
		_try_jump_toward(target)
		if target_dist_x > stop_distance:
			velocity.x = _direction * _move_speed
		else:
			velocity.x = 0.0
		if is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0

		if _weapon_state == WeaponState.SHOOTING and target_dist_x <= shoot_distance:
			_try_shoot_at(target)
		elif _weapon_state == WeaponState.PATROL and target_dist_x <= shoot_distance and _ammo_in_clip > 0:
			_weapon_state = WeaponState.SHOOTING

		if _weapon_state == WeaponState.SHOOTING and _ammo_in_clip <= 0:
			if _reloads_left > 0:
				_start_reload()
			else:
				_weapon_state = WeaponState.KNIFE
	else:
		_patrol_near_train()
		if is_on_floor() and velocity.y > 0.0:
			velocity.y = 0.0

func _try_jump_toward(target: Node2D) -> void:
	if target == null:
		return
	if not is_on_floor():
		return
	if _jump_timer > 0.0:
		return

	var dy := target.global_position.y - global_position.y
	var dx := absf(target.global_position.x - global_position.x)
	if dy < -jump_trigger_height and dx <= jump_trigger_distance:
		velocity.y = jump_velocity
		_jump_timer = jump_cooldown

func _patrol_near_train() -> void:
	if global_position.x <= _left_limit_global():
		_direction = 1
	elif global_position.x >= _right_limit_global():
		_direction = -1
	velocity.x = _direction * _move_speed
	_apply_visual_direction()

func _left_limit_global() -> float:
	return _patrol_anchor_x + _left_limit

func _right_limit_global() -> float:
	return _patrol_anchor_x + _right_limit

func _on_hitbox_body_entered(body: Node) -> void:
	if body is Person and body != self:
		_target_in_contact = body as Person

func _on_hitbox_body_exited(body: Node) -> void:
	if body == _target_in_contact:
		_target_in_contact = null

func _find_player() -> MainPerson:
	var scene = get_tree().current_scene
	if scene != null:
		var player = scene.get_node_or_null("Player")
		if player is MainPerson:
			return player as MainPerson
		return scene.find_node("Player", true, false) as MainPerson
	return null

func _pick_attack_target() -> Person:
	if _player != null and _player.is_inside_tree():
		return _player
	return _find_closest_passenger()

func _find_closest_passenger() -> Passenger:
	var passengers = get_tree().get_nodes_in_group("passenger")
	var closest: Passenger = null
	var best_dist := INF
	for node in passengers:
		if node is not Passenger:
			continue
		var passenger := node as Passenger
		if not passenger.is_inside_tree():
			continue
		var dist := global_position.distance_to(passenger.global_position)
		if dist < best_dist and dist <= detection_distance:
			best_dist = dist
			closest = passenger
	return closest

func _update_direction_toward(target_position: Vector2) -> void:
	_direction = 1 if target_position.x > global_position.x else -1
	_apply_visual_direction()

func _apply_visual_direction() -> void:
	if _sprite != null:
		_sprite.scale.x = _sprite_base_scale_x if _direction > 0 else -_sprite_base_scale_x

func _update_visual_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return

	if _shoot_anim_timer > 0.0:
		if _sprite.sprite_frames.has_animation("shoot") and _sprite.animation != "shoot":
			_sprite.play("shoot")
		return

	if _sprite.sprite_frames.has_animation("default") and _sprite.animation != "default":
		_sprite.play("default")

func _try_shoot_at(target: Person) -> void:
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

func _finish_reload() -> void:
	if _reloads_left > 0:
		_reloads_left -= 1
		_ammo_in_clip = clip_size
		_weapon_state = WeaponState.SHOOTING
	else:
		_weapon_state = WeaponState.KNIFE

func _shoot_at_target(target: Person) -> void:
	if not bullet_scene:
		push_warning("Enemy: назначь bullet_scene в инспекторе!")
		return

	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var shoot_dir := (target.global_position - global_position).normalized()
	bullet.direction = shoot_dir
	bullet.global_position = global_position + shoot_dir * 24.0
	_play_shot_feedback()
	if _audio != null and dst_shoot_sound != null:
		_audio.stop()
		_audio.stream = dst_shoot_sound
		_audio.play()

func _play_shot_feedback() -> void:
	if _sprite == null:
		return

	_shoot_anim_timer = 0.12
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation("shoot"):
		_sprite.play("shoot")
		_sprite.frame = 0
		return

	# Fallback if there is no dedicated shoot animation in sprite frames.
	_sprite.modulate = Color(1.25, 1.15, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.10)

func _apply_contact_damage() -> void:
	if _target_in_contact == null:
		return
	if not is_instance_valid(_target_in_contact):
		_target_in_contact = null
		return
	if _damage_timer > 0.0:
		return

	_target_in_contact.take_damage(_knife_damage if _weapon_state == WeaponState.KNIFE else _contact_damage)
	_damage_timer = _contact_damage_cooldown
