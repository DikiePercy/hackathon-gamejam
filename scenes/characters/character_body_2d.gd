extends CharacterBody2D

# === Настройки в инспекторе ===
@export var player: MainPerson         # Перетащи сюда своего игрока
@export var move_speed: float = 140.0        # Скорость движения
@export var attack_range: float = 55.0       # Расстояние, с которого начинает атаку

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false

func _physics_process(delta: float) -> void:
	if player == null:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Если враг атакует — ничего не делаем
	if is_attacking:
		return
	
	# === ПРЕСЛЕДОВАНИЕ ===
	if distance > attack_range:
		var direction = (player.global_position - global_position).normalized()
		
		velocity = direction * move_speed
		
		# Поворот спрайта
		sprite.flip_h = (direction.x < 0)
		
		# Анимация ходьбы
		if sprite.animation != "walk":
			sprite.play("walk")
		
		move_and_slide()
	
	# === АТАКА ===
	else:
		velocity = Vector2.ZERO
		
		# Поворачиваемся к игроку
		var dir_x = sign(player.global_position.x - global_position.x)
		sprite.flip_h = (dir_x < 0)
		
		# Запускаем атаку
		if sprite.animation != "attack":
			sprite.play("attack")
			is_attacking = true


# Когда анимация атаки закончилась
func _on_animated_sprite_2d_animation_finished() -> void:
	if sprite.animation == "attack":
		is_attacking = false
		# Можно добавить небольшую задержку перед следующей атакой
		await get_tree().create_timer(0.8).timeout
