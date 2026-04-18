extends Control

# Переменная, которая будет хранить ссылку на выбранный сейчас вагон
var selected_wagon = null

# Стоимость улучшения (можно менять)
var upgrade_cost = 100

@onready var info_label = $Label
@onready var upgrade_button = $UpgradeButton

# Ссылка на сцену вагона, чтобы создавать его копии
@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")

# Узел, куда будем складывать вагоны
@onready var train_preview = $TrainPreview

func refresh_train_preview():
	# 1. Сначала удаляем старые вагоны (если они были), чтобы не дублировались
	for child in train_preview.get_children():
		child.queue_free()
	
	# 2. Создаем вагоны на основе данных из GameManager
	# Допустим, в GameManager.wagon_levels лежит [1, 2]
	for i in range(GameManager.wagon_levels.size()):
		var level = GameManager.wagon_levels[i]
		
		# Создаем экземпляр вагона
		var new_wagon = wagon_scene.instantiate()
		
		# Устанавливаем ему уровень
		new_wagon.wagon_level = level
		
		# Расставляем их в ряд (например, с шагом 400 пикселей)
		# Локомотив обычно в 0, вагоны идут влево (в минус)
		new_wagon.position.x = -i * 400 
		
		# Добавляем в сцену
		train_preview.add_child(new_wagon)
		
		# СРАЗУ ПОДКЛЮЧАЕМ СИГНАЛ КЛИКА (о котором мы говорили раньше)
		new_wagon.clicked.connect(_on_wagon_clicked)
		
		# Обновляем внешний вид вагона прямо сейчас
		new_wagon.update_wagon_stats()

func _ready():
	
	refresh_train_preview()
	update_gold_ui()
	
	# Скрываем кнопку улучшения, пока вагон не выбран
	upgrade_button.disabled = true
	update_gold_ui()
	
	# ТУТ ВАЖНО: когда ты создаешь вагоны в депо кодом (instantiate),
	# ты должен подключить их сигнал к функции _on_wagon_clicked.
	# Пример:
	# var new_wagon = wagon_scene.instantiate()
	# new_wagon.clicked.connect(_on_wagon_clicked)
	# add_child(new_wagon)

# ЭТА ФУНКЦИЯ ЛОВИТ СИГНАЛ (тот самый self, который мы отправляли)
func _on_wagon_clicked(wagon_instance):
	# Запоминаем, какой вагон прислал сигнал
	selected_wagon = wagon_instance
	
	# Разблокируем кнопку
	upgrade_button.disabled = false
	
	# Обновляем текст
	info_label.text = "Выбран вагон " + wagon_instance.name + "\nУровень: " + str(selected_wagon.wagon_level)
	
	# Визуально выделяем вагон (например, чуть подсветим его)
	# Сначала сбросим цвет у всех остальных (если нужно), 
	# но для начала просто выведем в консоль:
	print("Депо получило вагон: ", selected_wagon)

# ФУНКЦИЯ ДЛЯ КНОПКИ "УЛУЧШИТЬ"
func _on_upgrade_button_pressed():
	if selected_wagon == null:
		return
		
	if GameManager.total_gold >= upgrade_cost:
		# 1. Забираем деньги
		GameManager.total_gold -= upgrade_cost
		
		# 2. Вызываем функцию улучшения ВНУТРИ самого вагона
		# Мы передали через сигнал весь объект, поэтому можем командовать им прямо отсюда!
		var success = selected_wagon.upgrade_wagon()
		
		if success:
			print("Вагон успешно прокачан!")
			# Обновляем текст в меню
			info_label.text = "Улучшено! Текущий уровень: " + str(selected_wagon.wagon_level)
			update_gold_ui()
		else:
			info_label.text = "Максимальный уровень достигнут!"
	else:
		info_label.text = "Недостаточно золота!"

func update_gold_ui():
	# Если у тебя есть Label для золота
	if has_node("GoldLabel"):
		$GoldLabel.text = "Золото: " + str(GameManager.total_gold)
