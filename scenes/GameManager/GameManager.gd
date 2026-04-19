extends Node

var total_gold = 5000
var has_shotgun: bool = false
var total_p = 100
var train_speed = 250

# Структура: [ [уровень, люди, hp], [уровень, люди, hp] ]
var train_data = [
	[1, 5, 1], # Первый вагон
	[1, 3, 2]  # Второй вагон
]

var train_level = 1 

func to_save_dict() -> Dictionary:
	return {
		"total_gold": total_gold,
		"has_shotgun": has_shotgun,
		"total_p": total_p,
		"train_speed": train_speed,
		"train_level": train_level,
		"train_data": train_data.duplicate(true)
	}

func apply_save_dict(data: Dictionary) -> void:
	total_gold = int(data.get("total_gold", total_gold))
	has_shotgun = bool(data.get("has_shotgun", has_shotgun))
	total_p = int(data.get("total_p", total_p))
	train_speed = int(data.get("train_speed", train_speed))
	train_level = int(data.get("train_level", train_level))

	var loaded_train_data = data.get("train_data", train_data)
	if loaded_train_data is Array and loaded_train_data.size() > 0:
		train_data = loaded_train_data.duplicate(true)
