extends Node2D

# Ссылка на контейнер, где лежат вагоны
@onready var wagons_container = $Wagons

# Ширина вагона (расстояние между точками крепления)
@export var wagon_width: float = 480.0

# Правильный способ указать путь к сцене через @export
@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")

var speed = 200.0
var passengers = 0

# Массив для быстрого доступа к объектам вагонов
var wagons = [] 

func _ready():
	# Обновляем список вагонов при старте
	update_wagon_list()
	add_wagon()



func add_wagon():
	# 1. Создаем экземпляр нового вагона
	var new_wagon = wagon_scene.instantiate()
	
	# 2. Считаем, сколько вагонов уже есть
	var current_wagon_count = wagons_container.get_child_count()
	
	# 3. Рассчитываем позицию по X
	# Если локомотив в 0, первый вагон будет в -400, второй в -800 и т.д.
	var offset_x = -(current_wagon_count + 1) * wagon_width
	new_wagon.position = Vector2(offset_x, 0)
	
	# 4. Добавляем вагон в сцену
	wagons_container.add_child(new_wagon)
	
	# Обновляем наш массив после добавления
	update_wagon_list()

# Функция для обновления массива (пригодится для разбойников)
func update_wagon_list():
	wagons = wagons_container.get_children()
