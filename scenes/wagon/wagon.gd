extends Node2D

signal clicked(wagon_node)
signal mouse_hovered(wagon_node)
signal mouse_unhovered(wagon_node)

var wagon_level = 1
var vagon_type = 1
var passengers = 0
var is_in_depot = false

const INTERIOR_Z_INDEX := 0
const PLAYER_INSIDE_Z_INDEX := 5
const EXTERIOR_Z_INDEX := 10
const DEFAULT_PLAYER_Z_INDEX := 1

@export var passenger_scene: PackedScene = preload("res://scenes/characters/passenger.tscn")

var money_per_level = {
	1: 10,
	2: 50,
	3: 100
}

# Ссылки на узлы по твоей структуре в wagon.tscn
@onready var interior_sprite: CanvasItem = _resolve_interior_sprite()
@onready var exterior_sprite: CanvasItem = _resolve_exterior_sprite()
@onready var _seat_markers_root: Node2D = $SeatMarkers

var _spawned_passengers: Array[Node2D] = []

func _ready():
	update_wagon_stats()
	# Настройка слоев "пирога" программно для надежности
	if interior_sprite:
		interior_sprite.z_as_relative = false
		interior_sprite.z_index = INTERIOR_Z_INDEX
	if exterior_sprite:
		exterior_sprite.z_as_relative = false
		exterior_sprite.z_index = EXTERIOR_Z_INDEX # Стенка всегда сверху
	
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
	var spawn_count := min(passengers, seats.size())

	for i in range(spawn_count):
		var seat := seats[i] as Marker2D
		if seat == null:
			continue
		var passenger_node := passenger_scene.instantiate()
		add_child(passenger_node)
		if passenger_node is Passenger:
			(passenger_node as Passenger).sit_at_global(seat.global_position)
		else:
			push_warning("wagon.gd: passenger_scene должен создавать Passenger")
			passenger_node.global_position = seat.global_position
		_spawned_passengers.append(passenger_node)

# ЭФФЕКТ НАРЕЗКИ
func _on_area_2d_body_entered(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	
	if exterior_sprite:
		var tween = create_tween()
		# Уводим стенку в 0.0 (полная прозрачность), чтобы точно видеть ковбоя
		tween.tween_property(exterior_sprite, "modulate:a", 0.0, 0.3)
	
	# Поднимаем игрока над интерьером, но под стенкой
	if not body.has_meta("_wagon_prev_z_index"):
		body.set_meta("_wagon_prev_z_index", body.z_index)
	if not body.has_meta("_wagon_prev_z_as_relative"):
		body.set_meta("_wagon_prev_z_as_relative", body.z_as_relative)
	body.z_as_relative = false
	body.z_index = PLAYER_INSIDE_Z_INDEX

func _on_area_2d_body_exited(body: Node2D) -> void:
	if not _is_player_body(body):
		return
	
	if exterior_sprite:
		var tween = create_tween()
		tween.tween_property(exterior_sprite, "modulate:a", 1.0, 0.3)
	
	# Возвращаем игрока на прежний слой
	if body.has_meta("_wagon_prev_z_as_relative"):
		body.z_as_relative = body.get_meta("_wagon_prev_z_as_relative")
		body.remove_meta("_wagon_prev_z_as_relative")
	else:
		body.z_as_relative = false
	if body.has_meta("_wagon_prev_z_index"):
		body.z_index = int(body.get_meta("_wagon_prev_z_index"))
		body.remove_meta("_wagon_prev_z_index")
	else:
		body.z_index = DEFAULT_PLAYER_Z_INDEX

# Сигналы кликов
func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", self)

func _is_player_body(body: Node) -> bool:
	if body == null:
		return false
	var body_name := body.name
	return body.is_in_group("player") or body.is_in_group("Player") or body_name == "player" or body_name == "Player"

func _resolve_interior_sprite() -> CanvasItem:
	var interior = get_node_or_null("Interiorsprite") as CanvasItem
	if interior != null:
		return interior
	return find_child("Interiorsprite", true, false) as CanvasItem

func _resolve_exterior_sprite() -> CanvasItem:
	var exterior = get_node_or_null("StaticBody2D/AnimatedSprite2D") as CanvasItem
	if exterior != null:
		return exterior
	return find_child("AnimatedSprite2D", true, false) as CanvasItem


func _on_area_2d_mouse_entered() -> void:
	emit_signal("mouse_hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("mouse_unhovered", self)
