extends Node2D

@onready var wagons_container = $Wagons
@onready var dst_train_engine_audio: AudioStreamPlayer = $TrainEngine
@onready var dst_train_horn_audio: AudioStreamPlayer = $TrainHorn
@export var wagon_width: float = 240.0
@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")

var speed = 200.0
var wagons = []
var is_in_depot = false

func _ready():
	# При старте уровня строим поезд по данным из GameManager
	if is_in_depot:
		if dst_train_engine_audio != null:
			dst_train_engine_audio.stop()
		if dst_train_horn_audio != null:
			dst_train_horn_audio.stop()
		return
	build_train_from_data()
	_play_train_horn()
	if speed > 0.0 and dst_train_engine_audio != null:
		dst_train_engine_audio.play()

func build_train_from_data():
	# Очищаем, если что-то было
	
	for child in wagons_container.get_children():
		child.queue_free()
	
	# Создаем вагоны на основе списка списков [уровень, люди]
	for i in range(GameManager.train_data.size()):
		var stats = GameManager.train_data[i]
		
		var new_wagon = wagon_scene.instantiate()
		new_wagon.vagon_type = stats[2]
		wagons_container.add_child(new_wagon)
		
		# Передаем данные
		new_wagon.wagon_level = stats[0]
		new_wagon.passengers = stats[1]
		
		# Позиция (смещение за локомотив)
		new_wagon.position.x = -(i + 1) * wagon_width
		new_wagon.position.y = position.y - 206
		
		# Обновляем статы
		if new_wagon.has_method("update_wagon_stats"):
			new_wagon.update_wagon_stats()
	
	update_wagon_list()

func update_wagon_list():
	wagons = wagons_container.get_children()

func _play_train_horn() -> void:
	if dst_train_horn_audio != null:
		dst_train_horn_audio.play()
