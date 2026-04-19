extends Node2D

@export var acceleration: float = 500.0 # Как быстро объект набирает скорость
var extra_speed: float = 0.0            # Добавочная скорость объекта
var is_active: bool = false

enum State {
	ACCELERATING,
	MOVING,
	DECELERATING
}

var state: State = State.ACCELERATING

var target_return_position: float = position.x

var dlina = 0

func _ready() -> void:
	$"../Train".go_trein.connect(_on_train_started)
	$"../Train".stop_trein.connect(_on_stop_train_started)

func _process(delta: float) -> void:
	# Базовая скорость берется из глобальной переменной
	var base_speed = GameManager.train_speed
	match state:
		State.ACCELERATING:
			extra_speed += acceleration * delta
			position.x -= (base_speed + extra_speed) * delta
			dlina += (base_speed + extra_speed) * delta
		State.MOVING:
			# держим скорость без изменений
			if is_active == true:
				position.x -= (base_speed + extra_speed) * delta
		
		State.DECELERATING:
			# телепорт в “точку возврата” один раз
			if is_active == true:
				position.x = target_return_position + dlina
				dlina = 0
				is_active = false
			
			if position.x > target_return_position:
				extra_speed -= acceleration * delta
				position.x -= (base_speed + extra_speed) * delta
				print(base_speed)
				
				
	state = State.MOVING
	
func _on_train_started():
	state = State.ACCELERATING
	is_active = true

func _on_stop_train_started():
	state = State.DECELERATING
	
