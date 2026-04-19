extends Control

@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")
@export var locomotive_scene: PackedScene = preload("res://scenes/train_timur/train.tscn")

@onready var train_preview = $TrainPreview
@onready var weapon_label = $Camera2D.get_node_or_null("WeaponLabel")
@onready var dst_depot_horn_audio: AudioStreamPlayer = $DepotHorn
@onready var dst_depot_buy_audio: AudioStreamPlayer = $DepotBuy
@onready var dst_depot_no_money_audio: AudioStreamPlayer = $DepotNoMoney

@export var shotgun_price: int = 600
@onready var gold_label = $CanvasLayer/VBoxContainer/HBoxContainer2/GoldLabel
@onready var p_label = $CanvasLayer/VBoxContainer/HBoxContainer2/VLabel
@onready var v_label = $CanvasLayer/VBoxContainer/HBoxContainer2/PLabel

@onready var camera = $Camera2D
var camera_speed = 500.0

var wagon_width = 240
var selected_wagon = null # Храним, какой вагон сейчас нажат

func _ready():
	draw_depot_train()
	update_ui()
	if dst_depot_horn_audio != null:
		dst_depot_horn_audio.play()

func _process(delta):
	# Создаем вектор направления движения
	var direction = 0
	
	# Проверяем нажатие клавиш A и D
	if Input.is_key_pressed(KEY_D):
		direction += 1
	if Input.is_key_pressed(KEY_A):
		direction -= 1
	
	# Двигаем камеру
	if direction != 0:
		camera.position.x += direction * camera_speed * delta

func draw_depot_train():
	# Очистка старых спрайтов
	for child in train_preview.get_children():
		child.queue_free()
	
	# 1. Сначала рисуем Локомотив
	var loco = locomotive_scene.instantiate()
	loco.is_in_depot = true
	add_child(loco)
	loco.position = Vector2(200, 150) # В депо локомотив в центре
	
	# 2. Рисуем вагоны из GameManager
	for i in range(GameManager.train_data.size()):
		var stats = GameManager.train_data[i]
		var new_wagon = wagon_scene.instantiate()
		new_wagon.is_in_depot = true
		new_wagon.vagon_type = stats[2]
		train_preview.add_child(new_wagon)
		
		new_wagon.wagon_level = stats[0]
		new_wagon.passengers = stats[1]
		new_wagon.position.x = (-(i + 1) * wagon_width) + 95
		new_wagon.position.y = loco.position.y - 58
		
		# ВАЖНО: В депо подключаем сигнал, чтобы ловить клики
		if new_wagon.has_signal("clicked"):
			new_wagon.clicked.connect(_on_wagon_selected)
		new_wagon.mouse_hovered.connect(_on_wagon_hover)
		new_wagon.mouse_unhovered.connect(_on_wagon_unhover)
		
		new_wagon.update_wagon_stats()

# Логика выбора вагона
func _on_wagon_selected(wagon_node):
	if selected_wagon:
		selected_wagon.modulate = Color(1, 1, 1) # Снимаем цвет с прошлого
	
	selected_wagon = wagon_node
	selected_wagon.modulate = Color(0.839, 0.93, 0.143, 1.0) # Подсвечиваем зеленым
	print("Выбран вагон с уровнем: ", selected_wagon.wagon_level)

# Кнопка улучшения в UI (подключи через сигнал pressed)
func _on_upgrade_button_pressed():
	if selected_wagon == null: return
	
	var price = 100
	if GameManager.total_gold >= price:
		# Находим индекс в массиве (индекс узла - 1, т.к. локо на 0 месте)
		var idx = selected_wagon.get_index() - 1
		
		if GameManager.train_data[idx][0] < 3:
			GameManager.total_gold -= price
			GameManager.train_data[idx][0] += 1 # Повышаем уровень в данных
			
			# Сразу обновляем визуал вагона, на который смотрим
			selected_wagon.wagon_level = GameManager.train_data[idx][0]
			selected_wagon.update_wagon_stats()
			
			update_ui()
			if dst_depot_buy_audio != null:
				dst_depot_buy_audio.play()
	else:
		print("Недостаточно золота!")
		if dst_depot_no_money_audio != null:
			dst_depot_no_money_audio.play()

func _on_wagon_hover(wagon_node):
	# Подсвечиваем, только если это НЕ уже выбранный вагон
	if wagon_node != selected_wagon:
		wagon_node.modulate = Color(1.2, 1.2, 1.2) # Слегка осветляем

func _on_wagon_unhover(wagon_node):
	# Возвращаем обычный цвет, только если это НЕ выбранный вагон
	if wagon_node != selected_wagon:
		wagon_node.modulate = Color(1, 1, 1)

func _on_buy_button_pressed() -> void:
	var wagon_price = 200
	if GameManager.total_gold >= wagon_price:
		# 1. Списываем золото
		GameManager.total_gold -= wagon_price
		
		# 2. Создаем "пакет данных" для нового вагона: [уровень 1, 0 человек]
		var randomv = randi_range(1, 3)
		var new_wagon_data = [1, 0, randomv]
		
		# 3. Добавляем эти данные в наш глобальный список в GameManager
		GameManager.train_data.append(new_wagon_data)
		
		# 4. ПОЛНОСТЬЮ перерисовываем поезд в Депо, чтобы увидеть новый вагон
		draw_depot_train()
		
		# 5. Обновляем текст с золотом
		update_ui()
		if dst_depot_buy_audio != null:
			dst_depot_buy_audio.play()
	else:
		print("Недостаточно золота!")
		if dst_depot_no_money_audio != null:
			dst_depot_no_money_audio.play()

func _on_buy_weapon_button_pressed() -> void:
	if GameManager.has_shotgun:
		print("Уже куплено ружье")
		return

	if GameManager.total_gold >= shotgun_price:
		GameManager.total_gold -= shotgun_price
		GameManager.has_shotgun = true
		update_ui()
		print("Куплено ружье!")
	else:
		print("Недостаточно золота для ружья!")
		if dst_depot_no_money_audio != null:
			dst_depot_no_money_audio.play()
	
func update_ui():
	gold_label.text = "Золото: " + str(GameManager.total_gold)
	if weapon_label != null:
		weapon_label.text = "Оружие: " + ("Ружье" if GameManager.has_shotgun else "Пистолет")
	v_label.text = "Патроны: " + str(GameManager.total_p)
	p_label.text = "Вагоны: " + str(GameManager.train_data.size())


func _on_buy_p_pressed() -> void:
	var p_price = 10
	if GameManager.total_gold >= p_price:
		# 1. Списываем золото
		GameManager.total_gold -= p_price
		
		# 2. Создаем "пакет данных" для нового вагона: [уровень 1, 0 человек], 3)
		
		# 3. Добавляем эти данные в наш глобальный список в GameManager
		GameManager.total_p += 1
		
		# 5. Обновляем текст с золотом
		update_ui()
		if dst_depot_buy_audio != null:
			dst_depot_buy_audio.play()
	else:
		print("Недостаточно золота!")
		if dst_depot_no_money_audio != null:
			dst_depot_no_money_audio.play()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
