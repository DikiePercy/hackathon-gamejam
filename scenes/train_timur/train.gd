extends Node2D

@onready var wagons_container = $Wagons
@onready var dst_train_engine_audio: AudioStreamPlayer = $TrainEngine
@onready var dst_train_horn_audio: AudioStreamPlayer = $TrainHorn
@export var wagon_width: float = 240.0
@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/characters/enemy.tscn")
@export var enemy_spawn_interval: float = 7.0
@export var enemy_spawn_max_active: int = 3



enum State {DRIVING, AT_STATION, SLOW, FAST}
var current_state = State.DRIVING

@export var max_speed: float = 300.0
@export var braking_distance: float = 500.0 # Дистанция начала торможения

var speed = 200.0
var wagons = []
var is_in_depot = false
var _active_enemies: Array[Node2D] = []
var _enemy_spawn_timer: Timer = null


const ENEMY_BULLET_SCENE := preload("res://scenes/characters/Bullet.tscn")
const ENEMY_SPAWN_OFFSET := Vector2(-220.0, 0.0)
const DEFAULT_BOARDING_OFFSET := Vector2(-200.0, -206.0)

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
	_setup_enemy_spawner()

func _process(delta: float) -> void:
	print(GameManager.train_speed)
	match current_state:
		State.DRIVING:
			drive_logic(delta)
		State.AT_STATION:
			station_logic(delta)
		State.SLOW:
			slow_logic(delta)
		State.FAST:
			fast_logic(delta)
	if is_in_depot:
		$Locomotive/AnimatedSprite2D.stop()

func slow_logic(delta):
	if GameManager.train_speed > 0:
		GameManager.train_speed -= 1
	else:
		current_state = State.AT_STATION

func fast_logic(delta):
	if GameManager.train_speed < max_speed:
		GameManager.train_speed += 1
	else:
		current_state = State.DRIVING

func drive_logic(delta):
	if !$Timer.is_stopped():
		print($Timer.time_left)
	else:
		$Timer.start(5)

func station_logic(_delta):
	pass
	
func _on_timer_timeout() -> void:
	current_state = State.SLOW
	print("Поезд stop!")

func _input(event):
	# "ui_accept" — это стандартное действие для Пробела (и Enter)
	if event.is_action_pressed("ui_accept") and current_state == State.AT_STATION:
		current_state = State.FAST

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
		new_wagon.position.y = position.y - 148
		
		# Обновляем статы
		if new_wagon.has_method("update_wagon_stats"):
			new_wagon.update_wagon_stats()
	
	update_wagon_list()

func update_wagon_list():
	wagons = wagons_container.get_children()

func _play_train_horn() -> void:
	if dst_train_horn_audio != null:
		dst_train_horn_audio.play()

func _setup_enemy_spawner() -> void:
	if enemy_scene == null:
		return
	if _enemy_spawn_timer == null:
		_enemy_spawn_timer = Timer.new()
		_enemy_spawn_timer.wait_time = enemy_spawn_interval
		_enemy_spawn_timer.one_shot = false
		_enemy_spawn_timer.autostart = false
		add_child(_enemy_spawn_timer)
		_enemy_spawn_timer.timeout.connect(_spawn_enemy_wave)
	_enemy_spawn_timer.start()

func _spawn_enemy_wave() -> void:
	_active_enemies = _active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	if _active_enemies.size() >= enemy_spawn_max_active:
		return

	var board_target := _get_boarding_target_position()
	var spawn_position := board_target + ENEMY_SPAWN_OFFSET
	var enemy_instance := enemy_scene.instantiate()
	if enemy_instance == null:
		return

	get_tree().current_scene.add_child(enemy_instance)
	if enemy_instance is Node2D:
		var enemy_2d := enemy_instance as Node2D
		enemy_2d.global_position = spawn_position
		_active_enemies.append(enemy_2d)

	if _has_property(enemy_instance, "bullet_scene"):
		enemy_instance.bullet_scene = ENEMY_BULLET_SCENE

	if enemy_instance.has_method("setup_for_train_raid"):
		enemy_instance.setup_for_train_raid(self, board_target)

func _get_boarding_target_position() -> Vector2:
	if wagons_container.get_child_count() == 0:
		return global_position + DEFAULT_BOARDING_OFFSET

	var rear_wagon := wagons_container.get_child(wagons_container.get_child_count() - 1) as Node2D
	if rear_wagon == null:
		return global_position + DEFAULT_BOARDING_OFFSET

	var boarding_marker := rear_wagon.get_node_or_null("Marker2D") as Marker2D
	if boarding_marker != null:
		return boarding_marker.global_position

	return rear_wagon.global_position + Vector2(-20.0, 0.0)

func _has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if property is Dictionary and property.get("name", "") == property_name:
			return true
	return false
