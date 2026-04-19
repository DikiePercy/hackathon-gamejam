extends Person
class_name MainPerson

const WALK_SPEED     := 180.0
const JUMP_VELOCITY  := -340.0
const GRAVITY        := 1000.0
const CLIMB_SPEED    := 160.0
const SHOOT_COOLDOWN := 0.25
const AIM_FLIP_DEADZONE := 0.2
const SHOOT_TURN_STOP_TIME := 0.3

const SHOOT_ANIM_TIME := 0.3
var _shoot_anim_timer := 0.0
var _is_drawing_back := false

const LAYER_INSIDE := 1
const LAYER_ROOF   := 2

enum State { GROUND, CLIMBING, ROOF }
var _state: State = State.GROUND

var _facing_right := true
var _aim_dir: Vector2 = Vector2.RIGHT
var _shoot_timer := 0.0
var _shoot_turn_stop_timer := 0.0
var _gun_local_x := 16.0

var _current_ladder: Area2D = null
var _ladder_top_y: float = 0.0
var _ladder_bottom_y: float = 0.0
var _train_node: Node2D = null
var _is_dead: bool = false

const ROOF_FALL_SWITCH_Y := 24.0
const RAIL_DEATH_BUFFER_Y := 10.0

@export var bullet_scene: PackedScene

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _gun_point: Marker2D = $GunPoint

func _ready() -> void:
	super._ready()
	_train_node = get_parent().get_node_or_null("Train") as Node2D
	_gun_local_x = absf(_gun_point.position.x)
	_sync_gun_point()
	_apply_collision(_state)
	if _sprite:
		_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	_shoot_anim_timer = maxf(_shoot_anim_timer - delta, 0.0)
	_shoot_turn_stop_timer = maxf(_shoot_turn_stop_timer - delta, 0.0)
	
	match _state:
		State.GROUND:
			_process_ground(delta)
		State.CLIMBING:
			_process_climbing()
		State.ROOF:
			_process_roof(delta)

	_update_aim_from_mouse()

	if Input.is_action_just_pressed("shoot") and _shoot_timer == 0.0:
		_shoot()

	_check_train_rail_fall_death()

	_update_anim()

func _process_ground(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	_move_x()

	if _current_ladder and Input.is_action_pressed("move_up") and is_on_floor():
		_set_state(State.CLIMBING)
		return

	move_and_slide()

func _process_climbing() -> void:
	velocity = Vector2.ZERO

	var dir_y := Input.get_axis("move_up", "move_down")
	velocity.y = dir_y * CLIMB_SPEED

	if _current_ladder:
		global_position.x = _current_ladder.global_position.x

	move_and_slide()

	if global_position.y <= _ladder_top_y:
		global_position.y = _ladder_top_y
		velocity = Vector2.ZERO
		_current_ladder = null
		_set_state(State.ROOF)
	elif _current_ladder and global_position.y >= _ladder_bottom_y:
		global_position.y = _ladder_bottom_y
		velocity = Vector2.ZERO
		_set_state(State.GROUND)

func _process_roof(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	_move_x()

	if _current_ladder and Input.is_action_pressed("move_down") and is_on_floor():
		velocity.y = CLIMB_SPEED
		_set_state(State.CLIMBING)
		return

	move_and_slide()

	var roof_y := _nearest_roof_y()
	if roof_y < INF and global_position.y > roof_y + ROOF_FALL_SWITCH_Y:
		_set_state(State.GROUND)

func _move_x() -> void:
	if _shoot_turn_stop_timer > 0.0:
		velocity.x = 0.0
		return

	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * WALK_SPEED
	if dir > 0.0:
		_set_facing(true)
	elif dir < 0.0:
		_set_facing(false)

func _sync_gun_point() -> void:
	_gun_point.position.x = _gun_local_x if _facing_right else -_gun_local_x

func _update_aim_from_mouse() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() <= 0.001:
		return

	_aim_dir = to_mouse.normalized()

	# Rotate to cursor only while idle to avoid twitching while running.
	if absf(velocity.x) <= 1.0:
		_apply_facing_from_aim()

func _apply_facing_from_aim() -> void:
	if _aim_dir.x > AIM_FLIP_DEADZONE:
		_set_facing(true)
	elif _aim_dir.x < -AIM_FLIP_DEADZONE:
		_set_facing(false)

func _set_facing(facing_right: bool) -> void:
	if _facing_right == facing_right:
		return
	_facing_right = facing_right
	_sprite.flip_h = not _facing_right
	_sync_gun_point()

func _set_state(s: State) -> void:
	if _is_dead:
		return
	_state = s
	_apply_collision(s)

func _apply_collision(s: State) -> void:
	match s:
		State.GROUND:
			set_collision_mask_value(LAYER_INSIDE, true)
			set_collision_mask_value(LAYER_ROOF, false)
		State.CLIMBING:
			set_collision_mask_value(LAYER_INSIDE, false)
			set_collision_mask_value(LAYER_ROOF, false)
		State.ROOF:
			set_collision_mask_value(LAYER_INSIDE, true)
			set_collision_mask_value(LAYER_ROOF, true)

func _shoot() -> void:
	if _is_dead:
		return
	if _is_drawing_back:
		return
	if not bullet_scene:
		push_warning("MainPerson: назначь bullet_scene в инспекторе!")
		return

	# On shoot: turn to cursor and briefly stop movement.
	_apply_facing_from_aim()
	_shoot_turn_stop_timer = SHOOT_TURN_STOP_TIME
	velocity.x = 0.0

	_shoot_timer = SHOOT_COOLDOWN
	_shoot_anim_timer = SHOOT_ANIM_TIME  # <-- добавь

	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var shoot_dir := _aim_dir
	bullet.direction = shoot_dir
	bullet.global_position = _gun_point.global_position + shoot_dir * 10.0

	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("shoot"):
		_sprite.play("shoot")             # <-- добавь
		_sprite.frame = 0                 # <-- чтобы стартовал с 1 кадра

func _on_ladder_detector_area_entered(area: Area2D) -> void:
	if not area.is_in_group("ladder"):
		return

	if area.has_meta("ladder_top_y") and area.has_meta("ladder_bottom_y"):
		_current_ladder = area
		_ladder_top_y = float(area.get_meta("ladder_top_y")) - 10.0
		_ladder_bottom_y = float(area.get_meta("ladder_bottom_y")) - 8.0
		return

	var col := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		for child in area.get_children():
			if child is CollisionShape2D:
				col = child as CollisionShape2D
				break
	if col == null:
		return

	var rect := col.shape as RectangleShape2D
	if rect == null:
		return

	_current_ladder = area
	var cy := area.global_position.y
	var hh := rect.size.y * 0.5
	_ladder_top_y = cy - hh + 6.0
	_ladder_bottom_y = cy + hh - 8.0

func _on_ladder_detector_area_exited(area: Area2D) -> void:
	if not area.is_in_group("ladder"):
		return
	_current_ladder = null
	if _state == State.CLIMBING:
		_set_state(State.GROUND)
		
func _update_anim() -> void:
	# Пока идёт draw — не перебиваем walking/idle/jump
	if _is_drawing_back:
		return
	
	if not _sprite or not _sprite.sprite_frames:
		return

	# 1) Приоритет выстрела
	if _shoot_anim_timer > 0.0 and _sprite.sprite_frames.has_animation("shoot"):
		if _sprite.animation != "shoot":
			_sprite.play("shoot")
		return

	# 2) Лазание
	if _state == State.CLIMBING and _sprite.sprite_frames.has_animation("climb"):
		if absf(velocity.y) > 1.0:
			_sprite.play("climb")
		else:
			_sprite.stop()
		return

	# 3) Прыжок/падение
	if not is_on_floor() and _sprite.sprite_frames.has_animation("jump"):
		_sprite.play("jump")
		return

	# 4) Бег/idle
	if absf(velocity.x) > 1.0 and _sprite.sprite_frames.has_animation("walking"):
		_sprite.play("walking")
	elif _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")

func _on_sprite_animation_finished() -> void:
	if _is_dead:
		return
	if not _sprite:
		return

	if _sprite.animation == "shoot":
		if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("draw"):
			_is_drawing_back = true
			_sprite.play("draw")
		else:
			_is_drawing_back = false

	elif _sprite.animation == "draw":
		_is_drawing_back = false

func is_dead() -> bool:
	return _is_dead

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	var body_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision != null:
		body_collision.disabled = true
	var ladder_collision := get_node_or_null("LadderDetector/CollisionShape2D") as CollisionShape2D
	if ladder_collision != null:
		ladder_collision.disabled = true

	if _sprite != null:
		_sprite.stop()
		_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
		_sprite.rotation_degrees = 90.0

	died.emit()

func _nearest_roof_y() -> float:
	if _train_node == null or not is_instance_valid(_train_node):
		_train_node = get_parent().get_node_or_null("Train") as Node2D
	if _train_node == null:
		return INF

	var wagons_node := _train_node.get_node_or_null("Wagons") as Node2D
	if wagons_node == null:
		return INF

	var nearest_y := INF
	var nearest_dx := INF
	for child in wagons_node.get_children():
		if child is not Node2D:
			continue
		var wagon := child as Node2D
		var roof_marker := wagon.get_node_or_null("RoofMarker") as Marker2D
		if roof_marker == null:
			continue
		var dx := absf(global_position.x - roof_marker.global_position.x)
		if dx < nearest_dx:
			nearest_dx = dx
			nearest_y = roof_marker.global_position.y

	return nearest_y

func _check_train_rail_fall_death() -> void:
	if _train_node == null or not is_instance_valid(_train_node):
		_train_node = get_parent().get_node_or_null("Train") as Node2D
	if _train_node == null:
		return
	if not _train_node.has_method("get_rear_guard_x"):
		return
	if not _train_node.has_method("get_rail_level_y"):
		return

	var guard_x := float(_train_node.call("get_rear_guard_x"))
	var rail_y := float(_train_node.call("get_rail_level_y"))
	if global_position.x < guard_x and global_position.y >= rail_y - RAIL_DEATH_BUFFER_Y:
		die()
