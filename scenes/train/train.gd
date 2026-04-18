extends Node2D

var speed = 200.0
var passengers = 0

# Список всех вагонов для разбойников
var wagons = [] 

func _ready():
	# Собираем все вагоны в массив при старте
	wagons = $WagonContainer.get_children()
