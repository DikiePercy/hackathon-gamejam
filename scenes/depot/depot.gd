extends Control

@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")
@export var locomotive_scene: PackedScene = preload("res://scenes/train/train.tscn")

@onready var train_preview = $TrainPreview
@onready var gold_label = $GoldLabel

var wagon_width = 480
var selected_wagon = null # Храним, какой вагон сейчас нажат

func _ready():
	draw_depot_train()
	update_ui()

func draw_depot_train():
	# Очистка старых спрайтов
	for child in train_preview.get_children():
		child.queue_free()
	
	# 1. Сначала рисуем Локомотив
	var loco = locomotive_scene.instantiate()
	train_preview.add_child(loco)
	loco.position = Vector2(600, 0) # В депо локомотив в центре
	
	# 2. Рисуем вагоны из GameManager
	for i in range(GameManager.train_data.size()):
		var stats = GameManager.train_data[i]
		var new_wagon = wagon_scene.instantiate()
		train_preview.add_child(new_wagon)
		
		new_wagon.wagon_level = stats[0]
		new_wagon.passengers = stats[1]
		new_wagon.position.x = (-(i + 1) * wagon_width) + 600
		
		# ВАЖНО: В депо подключаем сигнал, чтобы ловить клики
		if new_wagon.has_signal("clicked"):
			new_wagon.clicked.connect(_on_wagon_selected)
		
		new_wagon.update_wagon_stats()

# Логика выбора вагона
func _on_wagon_selected(wagon_node):
	if selected_wagon:
		selected_wagon.modulate = Color(1, 1, 1) # Снимаем цвет с прошлого
	
	selected_wagon = wagon_node
	selected_wagon.modulate = Color(0.5, 1, 0.5) # Подсвечиваем зеленым
	print("Выбран вагон с уровнем: ", selected_wagon.wagon_level)

# Кнопка улучшения в UI (подключи через сигнал pressed)
func _on_upgrade_button_pressed():
	if selected_wagon == null: return
	
	var price = 100
	if GameManager.total_gold >= price:
		# Находим индекс в массиве (индекс узла - 1, т.к. локо на 0 месте)
		var idx = selected_wagon.get_index() - 1
		
		GameManager.total_gold -= price
		GameManager.train_data[idx][0] += 1 # Повышаем уровень в данных
		
		# Сразу обновляем визуал вагона, на который смотрим
		selected_wagon.wagon_level = GameManager.train_data[idx][0]
		selected_wagon.update_wagon_stats()
		
		update_ui()
	else:
		print("Недостаточно золота!")

func update_ui():
	gold_label.text = "Золото: " + str(GameManager.total_gold)
