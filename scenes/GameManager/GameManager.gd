extends Node

var total_gold = 5000
var has_shotgun: bool = false
var total_p = 100
var train_speed = 0

# Структура: [ [уровень, люди, hp], [уровень, люди, hp] ]
var train_data = [
	[1, 5, 1], # Первый вагон
	[1, 3, 2]  # Второй вагон
]

var train_level = 1 
