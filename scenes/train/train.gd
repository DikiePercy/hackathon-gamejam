extends Node2D

# Назначь Wagon.tscn в инспекторе
@export var wagon_scene : PackedScene
@export var wagon_count : int   = 4
@export var train_speed : float = 0.0   # если > 0, поезд едет влево

var wagons : Array = []

const WAGON_WIDTH := 220.0
const WAGON_GAP   := 6.0
const LOCO_WIDTH  := 140.0

func _ready() -> void:
	_spawn_wagons()
	wagons = $WagonContainer.get_children()

func _process(delta: float) -> void:
	if train_speed > 0.0:
		position.x -= train_speed * delta

func _spawn_wagons() -> void:
	if not wagon_scene:
		push_warning("Train: назначь wagon_scene (Wagon.tscn) в инспекторе!")
		return
	for i in range(wagon_count):
		var w = wagon_scene.instantiate()
		$WagonContainer.add_child(w)
		w.position.x = LOCO_WIDTH + i * (WAGON_WIDTH + WAGON_GAP)
