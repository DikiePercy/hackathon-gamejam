extends Node2D

@export var speed: float = -GameManager.train_speed # Скорость в пикселях в секунду

func _process(delta):
	# Прибавляем скорость, умноженную на delta (чтобы движение было плавным)
	position.x += speed * delta
