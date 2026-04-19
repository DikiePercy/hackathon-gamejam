extends CharacterBody2D

@export var player: CharacterBody2D   # ← Перетащи сюда своего игрока в инспекторе

var is_attacking := false

func _physics_process(delta: float) -> void:
	if is_attacking and player:
		# Поворачиваем спрайт в сторону игрока во время атаки
		var dir_x = sign(player.global_position.x - global_position.x)
		$AnimatedSprite2D.flip_h = (dir_x < 0)


func start_attack() -> void:
	if player == null:
		return
	
	is_attacking = true
	
	# Сразу поворачиваем врага в сторону игрока перед атакой
	var dir_x = sign(player.global_position.x - global_position.x)
	$AnimatedSprite2D.flip_h = (dir_x < 0)
	
	# Запускаем анимацию атаки
	$AnimatedSprite2D.play("attack")
	
	# Здесь можешь добавить логику урона, звук и т.д.
	# Пример:
	# await get_tree().create_timer(0.3).timeout  # если урон в середине анимации
	# if global_position.distance_to(player.global_position) < 60:
	#     player.take_damage(15)


# Подключаем сигнал от AnimatedSprite2D
func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "attack":
		is_attacking = false
