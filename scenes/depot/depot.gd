extends Control

const TRAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const MAX_WAGONS := 5
const UPGRADE_PRICE := 100
const NEW_WAGON_PRICE := 200
const AMMO_PRICE := 10
const MAX_WAGON_LEVEL := 3

@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")
@export var locomotive_scene: PackedScene = preload("res://scenes/train_timur/train.tscn")

@onready var train_preview = $TrainPreview
@onready var weapon_label = $Camera2D.get_node_or_null("WeaponLabel")
@onready var dst_depot_music: AudioStreamPlayer = $DepotMusic
@onready var dst_depot_horn_audio: AudioStreamPlayer = $DepotHorn
@onready var dst_depot_buy_audio: AudioStreamPlayer = $DepotBuy
@onready var dst_depot_no_money_audio: AudioStreamPlayer = $DepotNoMoney

@export var shotgun_price: int = 600
@onready var gold_label = $CanvasLayer/VBoxContainer/HBoxContainer2/GoldLabel

@onready var upg_btn = $CanvasLayer/VBoxContainer/HBoxContainer/UpgradeButton
@onready var v_btn = $CanvasLayer/VBoxContainer/HBoxContainer/BuyButton
@onready var p_btn = $CanvasLayer/VBoxContainer/HBoxContainer/BuyP

@onready var camera = $Camera2D
var camera_speed: float = 500.0
var _depot_music_restart_timer := 60.0

var wagon_width: float = 240.0
var selected_wagon: Node2D = null

func _ready() -> void:
	_apply_pending_mission_reward()
	draw_depot_train()
	update_ui()
	if dst_depot_music != null:
		dst_depot_music.play()
		dst_depot_music.finished.connect(_on_depot_music_finished)
	if dst_depot_horn_audio != null:
		dst_depot_horn_audio.play()

func _on_depot_music_finished() -> void:
	if dst_depot_music != null:
		dst_depot_music.play()

func _process(delta: float) -> void:
	if dst_depot_music != null:
		_depot_music_restart_timer -= delta
		if _depot_music_restart_timer <= 0.0:
			_depot_music_restart_timer += 60.0
			dst_depot_music.play()
	var direction := 0
	
	# Проверяем нажатие клавиш A и D
	if Input.is_key_pressed(KEY_D):
		direction += 1
	if Input.is_key_pressed(KEY_A):
		direction -= 1
	
	# Двигаем камеру
	if direction != 0:
		camera.position.x += direction * camera_speed * delta

func draw_depot_train() -> void:
	# Очистка старых спрайтов
	for child in train_preview.get_children():
		child.queue_free()
	
	# 1. Сначала рисуем Локомотив
	var loco := locomotive_scene.instantiate()
	loco.is_in_depot = true
	add_child(loco)
	loco.position = Vector2(200, 100) # В депо локомотив в центре
	
	# 2. Рисуем вагоны из GameManager
	for i in range(GameManager.train_data.size()):
		var stats: Array = GameManager.train_data[i]
		var new_wagon := wagon_scene.instantiate()
		new_wagon.is_in_depot = true
		new_wagon.vagon_type = stats[2]
		train_preview.add_child(new_wagon)
		
		new_wagon.wagon_level = stats[0]
		new_wagon.passengers = stats[1]
		new_wagon.position.x = (-(i + 1) * wagon_width) + 95
		new_wagon.position.y = loco.position.y - 35
		
		# ВАЖНО: В депо подключаем сигнал, чтобы ловить клики
		if new_wagon.has_signal("clicked"):
			new_wagon.clicked.connect(_on_wagon_selected)
		new_wagon.mouse_hovered.connect(_on_wagon_hover)
		new_wagon.mouse_unhovered.connect(_on_wagon_unhover)
		
		new_wagon.update_wagon_stats()

# Логика выбора вагона
func _on_wagon_selected(wagon_node: Node2D) -> void:
	if selected_wagon:
		selected_wagon.modulate = Color(1, 1, 1) # Снимаем цвет с прошлого
	
	selected_wagon = wagon_node
	selected_wagon.modulate = Color(0.839, 0.93, 0.143, 1.0) # Подсвечиваем зеленым
	print("Выбран вагон с уровнем: ", selected_wagon.wagon_level)

# Кнопка улучшения в UI (подключи через сигнал pressed)
func _on_upgrade_button_pressed() -> void:
	if selected_wagon == null:
		return

	var idx := selected_wagon.get_index() - 1
	if idx < 0 or idx >= GameManager.train_data.size():
		return

	if GameManager.train_data[idx][0] >= MAX_WAGON_LEVEL:
		return

	if not _try_spend_gold(UPGRADE_PRICE):
		return

	GameManager.train_data[idx][0] += 1
	selected_wagon.wagon_level = GameManager.train_data[idx][0]
	selected_wagon.update_wagon_stats()
	update_ui()
	_play_buy_audio()

func _on_wagon_hover(wagon_node: Node2D) -> void:
	# Подсвечиваем, только если это НЕ уже выбранный вагон
	if wagon_node != selected_wagon:
		wagon_node.modulate = Color(1.2, 1.2, 1.2) # Слегка осветляем

func _on_wagon_unhover(wagon_node: Node2D) -> void:
	# Возвращаем обычный цвет, только если это НЕ выбранный вагон
	if wagon_node != selected_wagon:
		wagon_node.modulate = Color(1, 1, 1)

func _on_buy_button_pressed() -> void:
	if GameManager.train_data.size() >= MAX_WAGONS:
		print("максимул вагонов")
		return

	if not _try_spend_gold(NEW_WAGON_PRICE):
		return

	var randomv := randi_range(1, 3)
	var new_wagon_data := [1, 0, randomv]
	GameManager.train_data.append(new_wagon_data)

	draw_depot_train()
	update_ui()
	_play_buy_audio()

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
		_play_not_enough_gold_feedback("Недостаточно золота для ружья!")
	
func update_ui() -> void:
	gold_label.text = "Золото: " + str(GameManager.total_gold)
	if weapon_label != null:
		weapon_label.text = "Оружие: " + ("Ружье" if GameManager.has_shotgun else "Пистолет")
	p_btn.text = str(GameManager.total_p)
	v_btn.text = str(GameManager.train_data.size())


func _on_buy_p_pressed() -> void:
	if not _try_spend_gold(AMMO_PRICE):
		return

	GameManager.total_p += 1
	update_ui()
	_play_buy_audio()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TRAIN_SCENE_PATH)

func _apply_pending_mission_reward() -> void:
	if GameManager.pending_mission_reward == 0:
		return
	var reward := GameManager.pending_mission_reward
	GameManager.pending_mission_reward = 0
	if reward >= 0:
		print("Награда за рейс: +", reward)
	else:
		print("Штраф за провал рейса: ", reward)

func _try_spend_gold(amount: int) -> bool:
	if GameManager.total_gold < amount:
		_play_not_enough_gold_feedback("Недостаточно золота!")
		return false
	GameManager.total_gold -= amount
	return true

func _play_buy_audio() -> void:
	if dst_depot_buy_audio != null:
		dst_depot_buy_audio.play()

func _play_not_enough_gold_feedback(message: String) -> void:
	print(message)
	if dst_depot_no_money_audio != null:
		dst_depot_no_money_audio.play()
