extends Node2D

@export var acceleration: float = 500.0 # Как быстро объект набирает скорость
var extra_speed: float = 0.0            # Добавочная скорость объекта
var is_active: bool = false

func _ready() -> void:
	$"../Train".go_trein.connect(_on_train_started)
	$"../Train".stop_trein.connect(_on_stop_train_started)

func _process(delta: float) -> void:
	# Базовая скорость берется из глобальной переменной
	var base_speed = GameManager.train_speed
	
	if is_active:
		# Наращиваем добавочную скорость
		extra_speed += acceleration * delta
	
	# Итоговая скорость = скорость поезда + наше ускорение
	# Двигаем влево (поэтому минус)
	position.x -= (base_speed + extra_speed) * delta

func _on_train_started():
	is_active = true
	# Если нужно сбросить ускорение при старте:
	# extra_speed = 0.0 

func _on_stop_train_started():
	is_active = true
