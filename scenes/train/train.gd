# res://scenes/train/train.gd
extends Node2D

@export var wagon_scene: PackedScene
@export var enemy_scene: PackedScene
@export var wagon_count: int = 4
@export var wagon_spacing: float = 240.0
@export var train_speed: float = 0.0
@export var spawn_enemy_on_each_wagon: bool = true

@onready var _wagon_container: Node2D = $WagonContainer


func _ready() -> void:
	_spawn_wagons()
	if spawn_enemy_on_each_wagon:
		_spawn_enemies()


func _process(delta: float) -> void:
	if train_speed > 0.0:
		position.x -= train_speed * delta


func _spawn_wagons() -> void:
	if wagon_scene == null:
		push_error("Train: wagon_scene не назначен в инспекторе")
		return

	# Чистим контейнер перед спавном
	for child in _wagon_container.get_children():
		child.queue_free()

	for i in wagon_count:
		var wagon := wagon_scene.instantiate()
		wagon.position = Vector2(i * wagon_spacing, 0.0)
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
		enemy.global_position = marker.global_position
		_wagon_container.add_child(enemy)
