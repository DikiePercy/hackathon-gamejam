extends Person
class_name MainPerson

const WALK_SPEED     := 180.0
const JUMP_VELOCITY  := -340.0
const GRAVITY        := 1000.0
const CLIMB_SPEED    := 160.0
const SHOOT_COOLDOWN := 0.25

const SHOOT_ANIM_TIME := 0.3
var _shoot_anim_timer := 0.0
var _is_drawing_back := false

const LAYER_INSIDE := 1
const LAYER_ROOF   := 2

enum State { GROUND, CLIMBING, ROOF }
var _state: State = State.GROUND

var _facing_right := true
var _shoot_timer := 0.0
var _gun_local_x := 16.0

var _current_ladder: Area2D = null
var _ladder_top_y: float = 0.0
var _ladder_bottom_y: float = 0.0

@export var bullet_scene: PackedScene

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _gun_point: Marker2D = $GunPoint

func _ready() -> void:
	super._ready()
	_gun_local_x = absf(_gun_point.position.x)
	_sync_gun_point()
	_apply_collision(_state)
	if _sprite:
		_sprite.animation_finished.connect(_on_sprite_animation_finished)

func _physics_process(delta: float) -> void:
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)
	_shoot_anim_timer = maxf(_shoot_anim_timer - delta, 0.0)
	
	match _state:
		State.GROUND:
			_process_ground(delta)
		State.CLIMBING:
			_process_climbing()
		State.ROOF:
			_process_roof(delta)

	if Input.is_action_just_pressed("shoot") and _shoot_timer == 0.0:
		_shoot()

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
		_set_state(State.ROOF)
	elif _current_ladder and global_position.y >= _ladder_bottom_y:
		global_position.y = _ladder_bottom_y
		_set_state(State.GROUND)

func _process_roof(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	_move_x()

	if _current_ladder and Input.is_action_pressed("move_down") and is_on_floor():
		velocity.y = CLIMB_SPEED
		_set_state(State.CLIMBING)
		return

	move_and_slide()

func _move_x() -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * WALK_SPEED
	if dir > 0.0:
		_facing_right = true
		_sprite.flip_h = false
		_sync_gun_point()
	elif dir < 0.0:
		_facing_right = false
		_sprite.flip_h = true
		_sync_gun_point()

func _sync_gun_point() -> void:
	_gun_point.position.x = _gun_local_x if _facing_right else -_gun_local_x

func _set_state(s: State) -> void:
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
			set_collision_mask_value(LAYER_INSIDE, false)
			set_collision_mask_value(LAYER_ROOF, true)

func _shoot() -> void:
	if _is_drawing_back:
		return
	if not bullet_scene:
		push_warning("MainPerson: назначь bullet_scene в инспекторе!")
		return

	_shoot_timer = SHOOT_COOLDOWN
	_shoot_anim_timer = SHOOT_ANIM_TIME  # <-- добавь

	var bullet: Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var shoot_dir := Vector2.RIGHT if _facing_right else Vector2.LEFT
	bullet.direction = shoot_dir
	bullet.global_position = _gun_point.global_position + shoot_dir * 10.0

	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation("shoot"):
		_sprite.play("shoot")             # <-- добавь
		_sprite.frame = 0                 # <-- чтобы стартовал с 1 кадра

func _on_ladder_detector_area_entered(area: Area2D) -> void:
	if not area.is_in_group("ladder"):
		return
	_current_ladder = area
	var col := area.get_node("CollisionShape2D") as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	var cy := area.global_position.y
	var hh := rect.size.y * 0.5
	_ladder_top_y = cy - hh + 16.0
	_ladder_bottom_y = cy + hh - 16.0

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
