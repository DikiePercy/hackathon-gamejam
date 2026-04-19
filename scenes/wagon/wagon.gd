extends Node2D

signal clicked(wagon_node)
signal mouse_hovered(wagon_node)
signal mouse_unhovered(wagon_node)

var wagon_level = 1
var vagon_type = 1
var passengers = 0

@export var passenger_scene: PackedScene = preload("res://scenes/characters/passenger.tscn")

var money_per_level = {
	1: 10,
	2: 50,
	3: 100
}

# Ссылки на узлы по твоей структуре в wagon.tscn
@onready var interior_sprite = $Interiorsprite
@onready var exterior_sprite = $StaticBody2D/AnimatedSprite2D
@onready var _seat_markers_root: Node2D = $SeatMarkers

var _spawned_passengers: Array[Node2D] = []

func _ready():
	update_wagon_stats()
	# Настройка слоев "пирога" программно для надежности
	if interior_sprite: interior_sprite.z_index = 0
	if exterior_sprite: exterior_sprite.z_index = 10 # Стенка всегда сверху
	
	if interior_sprite and interior_sprite.has_method("play"):
		interior_sprite.play("v" + str(vagon_type))
	if exterior_sprite and exterior_sprite.has_method("play"):
		exterior_sprite.play("v" + str(vagon_type))
	call_deferred("sync_passengers")

func update_wagon_stats():
	if not is_inside_tree(): return
	var target_color = Color(1, 1, 1)
	match wagon_level:
		1: target_color = Color(1, 1, 1)
		2: target_color = Color(0.7, 0.7, 1)
		3: target_color = Color(1, 0.9, 0.4)

	if interior_sprite: interior_sprite.modulate = target_color
	if exterior_sprite: exterior_sprite.modulate = target_color

func sync_passengers() -> void:
	for passenger_node in _spawned_passengers:
		if is_instance_valid(passenger_node):
			passenger_node.queue_free()
	_spawned_passengers.clear()

	if passenger_scene == null or _seat_markers_root == null:
		return

	var seats := _seat_markers_root.get_children()
	var spawn_count := mini(passengers, seats.size())

	for i in range(spawn_count):
		var seat := seats[i] as Marker2D
		if seat == null:
			continue
		var passenger_node := passenger_scene.instantiate()
		add_child(passenger_node)
		if passenger_node is Passenger:
			(passenger_node as Passenger).sit_at_global(seat.global_position)
		else:
			passenger_node.global_position = seat.global_position
		_spawned_passengers.append(passenger_node)

# ЭФФЕКТ НАРЕЗКИ
func _on_area_2d_body_entered(body: Node2D) -> void:
	# Проверяем группу "player" (убедись, что в Player.tscn группа именно такая)
	if body.is_in_group("player") or body.name == "Player":
		if exterior_sprite:
			var tween = create_tween()
			# Уводим стенку в 0.0 (полная прозрачность), чтобы точно видеть ковбоя
			tween.tween_property(exterior_sprite, "modulate:a", 0.0, 0.3)
			# Поднимаем игрока над интерьером, но под стенку
			body.z_index = 5 

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if exterior_sprite:
			var tween = create_tween()
			tween.tween_property(exterior_sprite, "modulate:a", 1.0, 0.3)
			# Возвращаем игрока на стандартный слой
			body.z_index = 1 

# Сигналы кликов
func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", self)

func _on_area_2d_mouse_entered() -> void:
	emit_signal("mouse_hovered", self)

func _on_area_2d_mouse_exited() -> void:
	emit_signal("mouse_unhovered", self)
