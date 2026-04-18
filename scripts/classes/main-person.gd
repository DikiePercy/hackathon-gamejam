extends Person
class_name MainPerson

const WALK_SPEED     := 220.0   
const JUMP_VELOCITY  := -460.0  
const GRAVITY        := 1000.0 
const CLIMB_SPEED    := 160.0 
const SHOOT_COOLDOWN := 0.25   
const KICK_FORCE_X   := 500.0   # горизонтальная сила удара
const KICK_FORCE_Y   := -150.0  # вертикальная составляющая удара

const LAYER_INSIDE := 1   
const LAYER_ROOF   := 2   

enum State { GROUND, CLIMBING, ROOF }
var _state: State = State.GROUND

var _facing_right  := true
var _shoot_timer   := 0.0

var _current_ladder  : Area2D = null
var _ladder_top_y    : float  = 0.0
var _ladder_bottom_y : float  = 0.0

@export var bullet_scene: PackedScene

@onready var _sprite          : ColorRect = $Sprite
@onready var _gun_point       : Marker2D  = $GunPoint
@onready var _ladder_detector : Area2D    = $LadderDetector

func _ready() -> void:
	super._ready()
	_apply_collision(_state)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)   # обновляет _knockback_timer в Person
	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	# Пока действует кнокбэк — управление заблокировано,
	# но гравитация продолжает тянуть вниз.
	if is_knocked_back():
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	match _state:
		State.GROUND:   _process_ground(delta)
		State.CLIMBING: _process_climbing()
		State.ROOF:     _process_roof(delta)

	if Input.is_action_just_pressed("shoot") and _shoot_timer == 0.0:
		_shoot()

	if Input.is_action_just_pressed("kick"):
		_try_kick()

func _process_ground(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	_move_x()
	
	if _current_ladder and Input.is_action_pressed("ui_up") and is_on_floor():
		_set_state(State.CLIMBING)
		return

	move_and_slide()

func _process_climbing() -> void:
	velocity = Vector2.ZERO

	var dir_y := Input.get_axis("ui_up", "ui_down")  # -1=вверх, +1=вниз
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

	# S / Вниз у лестницы → слезть
	if _current_ladder and Input.is_action_pressed("ui_down") and is_on_floor():
		velocity.y = CLIMB_SPEED
		_set_state(State.CLIMBING)
		return

	move_and_slide()

func _move_x() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * WALK_SPEED
	if dir > 0.0:
		_facing_right = true
		_sprite.scale.x = 1.0
	elif dir < 0.0:
		_facing_right = false
		_sprite.scale.x = -1.0

func _set_state(s: State) -> void:
	_state = s
	_apply_collision(s)

func _apply_collision(s: State) -> void:
	match s:
		State.GROUND:
			set_collision_mask_value(LAYER_INSIDE, true)
			set_collision_mask_value(LAYER_ROOF,   false)
		State.CLIMBING:
			set_collision_mask_value(LAYER_INSIDE, false)
			set_collision_mask_value(LAYER_ROOF,   false)
		State.ROOF:
			set_collision_mask_value(LAYER_INSIDE, false)
			set_collision_mask_value(LAYER_ROOF,   true)

func _shoot() -> void:
	if not bullet_scene:
		push_warning("MainPerson: назначь bullet_scene в инспекторе!")
		return
	_shoot_timer = SHOOT_COOLDOWN
	var bullet : Node2D = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = _gun_point.global_position
	bullet.direction = Vector2.RIGHT if _facing_right else Vector2.LEFT

func _on_ladder_detector_area_entered(area: Area2D) -> void:
	if not area.is_in_group("ladder"):
		return
	_current_ladder = area
	var col  := area.get_node("CollisionShape2D") as CollisionShape2D
	var rect := col.shape as RectangleShape2D
	var cy   := area.global_position.y
	var hh   := rect.size.y * 0.5
	_ladder_top_y    = cy - hh + 16.0 
	_ladder_bottom_y = cy + hh - 16.0

func _on_ladder_detector_area_exited(area: Area2D) -> void:
	if not area.is_in_group("ladder"):
		return
	_current_ladder = null
	if _state == State.CLIMBING:
		_set_state(State.GROUND)
