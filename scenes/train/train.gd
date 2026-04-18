# res://scenes/train/train.gd
extends Node2D

@export var wagon_scene: PackedScene
@export var enemy_scene: PackedScene
@export var passenger_scene: PackedScene
@export var wagon_count: int = 4
@export var wagon_spacing: float = 240.0
@export var train_speed: float = 0.0
@export var spawn_enemy_on_each_wagon: bool = true
@export var spawn_passengers: bool = true

@onready var _wagon_container: Node2D = $WagonContainer


func _ready() -> void:
	_spawn_wagons()
	if spawn_enemy_on_each_wagon:
		_spawn_enemies()
	if spawn_passengers:
		_spawn_passengers()


func _process(delta: float) -> void:
	if train_speed > 0.0:
		position.x -= train_speed * delta


func _spawn_wagons() -> void:
	if wagon_scene == null:
		push_error("Train: wagon_scene не назначен в инспекторе")
		return

	for child in _wagon_container.get_children():
		child.queue_free()

	for i in wagon_count:
		var wagon := wagon_scene.instantiate()
		wagon.position = Vector2(-(i + 1) * wagon_spacing, 0.0)
		_wagon_container.add_child(wagon)


func _spawn_enemies() -> void:
	if enemy_scene == null:
		push_warning("Train: enemy_scene не назначен — враги не будут заспавнены")
		return

	for wagon in _wagon_container.get_children():
		var marker: Marker2D = wagon.get_node_or_null("EnemySpawnPoint")
		if marker == null:
			continue

		var enemy := enemy_scene.instantiate()
		enemy.position = marker.position
		wagon.add_child(enemy)


func _spawn_passengers() -> void:
	if passenger_scene == null:
		push_warning("Train: passenger_scene не назначен — пассажиры не будут заспавнены")
		return

	for wagon in _wagon_container.get_children():
		var seats: Node = wagon.get_node_or_null("Seats")
		if seats == null:
			continue

		for seat in seats.get_children():
			if not seat is Marker2D:
				continue

			var passenger := passenger_scene.instantiate()
			if passenger.has_method("sit_at_global"):
				wagon.add_child(passenger)
				passenger.sit_at_global((seat as Marker2D).global_position)
			else:
				passenger.position = (seat as Marker2D).position
				wagon.add_child(passenger)
