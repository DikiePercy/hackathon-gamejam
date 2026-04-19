extends MainPerson
class_name MultiplayerPawn

signal shot_fired(origin: Vector2, direction: Vector2)

var is_local: bool = false
var _hp: int = 100

func _ready() -> void:
	super._ready()

func _physics_process(delta: float) -> void:
	if not is_local:
		# Удалённый игрок — только гравитация и слайд
		velocity.y += GRAVITY * delta
		velocity.x = 0.0
		move_and_slide()
		_update_anim()
		return
	# Локальный — полное управление через родительский класс
	super._physics_process(delta)

# Перехватываем выстрел и отправляем по сети
func _shoot() -> void:
	super._shoot()
	emit_signal("shot_fired", _gun_point.global_position, _aim_dir)

func get_network_state() -> Dictionary:
	return {
		"position": global_position,
		"facing_right": _facing_right,
		"aim_direction": _aim_dir,
		"anim_state": int(_state)
	}

func set_remote_state(new_position: Vector2, facing: bool, aim_dir: Vector2, anim_state: int) -> void:
	global_position = new_position
	_facing_right = facing
	_aim_dir = aim_dir
	_state = anim_state as State
	if _sprite:
		_sprite.flip_h = not facing
	_sync_gun_point()

func take_damage(amount: int) -> void:
	_hp -= amount
	if _hp <= 0:
		_die()

func _die() -> void:
	queue_free()
