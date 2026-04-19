extends Node2D

@onready var wagons_container = $Wagons
@onready var ladders_container: Node2D = $Ladders
@onready var dst_train_engine_audio: AudioStreamPlayer = $TrainEngine
@onready var dst_train_horn_audio: AudioStreamPlayer = $TrainHorn
@export var wagon_width: float = 240.0
@export var wagon_scene: PackedScene = preload("res://scenes/wagon/wagon.tscn")
@export var enemy_scene: PackedScene = preload("res://scenes/characters/character_body_2d.tscn")
@export var enemy_spawn_interval: float = 12.0
@export var enemy_spawn_max_active: int = 4
@export var enemy_wave_min_size: int = 2
@export var enemy_wave_max_size: int = 3
@export var enemy_wave_member_delay: float = 0.35
@export var enemy_assault_delay_min: float = 0.25
@export var enemy_assault_delay_max: float = 0.8

var speed = 200.0
var wagons = []
var is_in_depot = false
var _active_enemies: Array[Node2D] = []
var _enemy_spawn_timer: Timer = null
var _last_lane_id: int = -1

const ENEMY_BULLET_SCENE := preload("res://scenes/characters/Bullet.tscn")
const ENEMY_SPAWN_OFFSET := Vector2(-220.0, 0.0)
const DEFAULT_BOARDING_OFFSET := Vector2(-200.0, -206.0)
const DEFAULT_INTERIOR_OFFSET := Vector2(-90.0, -206.0)
const DEFAULT_ROOF_OFFSET := Vector2(-10.0, -244.0)
const LANE_REAR := 0
const LANE_MID := 1
const LANE_FRONT := 2
const LADDER_LAYER_BIT := 4
const LADDER_WIDTH := 24.0
const LADDER_EXTRA_HEIGHT := 22.0

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

func _process(_delta: float) -> void:
	if is_in_depot:
		$Locomotive/AnimatedSprite2D.stop()

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
	_rebuild_ladders()

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
	var free_slots: int = enemy_spawn_max_active - _active_enemies.size()
	if free_slots <= 0:
		return

	var requested_wave_size: int = randi_range(enemy_wave_min_size, enemy_wave_max_size)
	var wave_size: int = mini(requested_wave_size, free_slots)
	if wave_size <= 0:
		return

	for i in range(wave_size):
		var lane_id: int = _pick_next_lane_id()
		var member_delay: float = enemy_wave_member_delay * float(i)
		_spawn_enemy_member(lane_id, member_delay)

func _spawn_enemy_member(lane_id: int, delay_seconds: float) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout

	_active_enemies = _active_enemies.filter(func(enemy): return is_instance_valid(enemy))
	if _active_enemies.size() >= enemy_spawn_max_active:
		return

	if enemy_scene == null:
		return

	var board_target: Vector2 = get_enemy_boarding_target(lane_id)
	var spawn_position: Vector2 = board_target + ENEMY_SPAWN_OFFSET
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

	if _has_property(enemy_instance, "assault_delay"):
		enemy_instance.assault_delay = randf_range(enemy_assault_delay_min, enemy_assault_delay_max)

	if enemy_instance.has_method("setup_for_train_raid"):
		enemy_instance.setup_for_train_raid(self, board_target, lane_id)

func _pick_next_lane_id() -> int:
	var available_lanes: Array[int] = _get_available_lane_ids()
	if available_lanes.is_empty():
		return LANE_REAR

	for lane in available_lanes:
		if lane != _last_lane_id:
			_last_lane_id = lane
			return lane

	_last_lane_id = available_lanes[0]
	return _last_lane_id

func _get_available_lane_ids() -> Array[int]:
	var lane_ids: Array[int] = []
	if wagons_container.get_child_count() <= 0:
		lane_ids.append(LANE_REAR)
		return lane_ids

	lane_ids.append(LANE_REAR)
	if wagons_container.get_child_count() >= 2:
		lane_ids.append(LANE_MID)
	if wagons_container.get_child_count() >= 3:
		lane_ids.append(LANE_FRONT)
	return lane_ids

func get_enemy_boarding_target(lane_id: int = LANE_REAR) -> Vector2:
	if wagons_container.get_child_count() == 0:
		return global_position + DEFAULT_BOARDING_OFFSET

	var lane_wagon: Node2D = _get_lane_wagon(lane_id)
	if lane_wagon == null:
		return global_position + DEFAULT_BOARDING_OFFSET

	return _resolve_lane_marker_or_fallback(lane_wagon, "Marker2D", Vector2(-20.0, 0.0))

func get_enemy_interior_target(lane_id: int = LANE_REAR) -> Vector2:
	if wagons_container.get_child_count() == 0:
		return global_position + DEFAULT_INTERIOR_OFFSET

	var lane_wagon: Node2D = _get_lane_wagon(lane_id)
	if lane_wagon == null:
		return global_position + DEFAULT_INTERIOR_OFFSET

	return _resolve_lane_marker_or_fallback(lane_wagon, "InteriorEntry", Vector2(-90.0, 0.0))

func get_enemy_roof_target(lane_id: int = LANE_REAR) -> Vector2:
	if wagons_container.get_child_count() == 0:
		return global_position + DEFAULT_ROOF_OFFSET

	var lane_wagon: Node2D = _get_lane_wagon(lane_id)
	if lane_wagon == null:
		return global_position + DEFAULT_ROOF_OFFSET

	return _resolve_lane_marker_or_fallback(lane_wagon, "RoofMarker", Vector2(-10.0, -40.0))

func _get_lane_wagon(lane_id: int) -> Node2D:
	var wagon_count: int = wagons_container.get_child_count()
	if wagon_count <= 0:
		return null

	var index: int = wagon_count - 1
	if lane_id == LANE_FRONT:
		index = 0
	elif lane_id == LANE_MID:
		index = int(floor(float(wagon_count - 1) / 2.0))

	return wagons_container.get_child(index) as Node2D

func _resolve_lane_marker_or_fallback(wagon_node: Node2D, marker_name: String, fallback_offset: Vector2) -> Vector2:
	if wagon_node == null:
		return global_position + fallback_offset

	var marker := wagon_node.get_node_or_null(marker_name) as Marker2D
	if marker != null:
		return marker.global_position

	return wagon_node.global_position + fallback_offset

func _has_property(node: Object, property_name: String) -> bool:
	for property in node.get_property_list():
		if property is Dictionary and property.get("name", "") == property_name:
			return true
	return false

func _rebuild_ladders() -> void:
	if ladders_container == null:
		return

	for child in ladders_container.get_children():
		child.queue_free()

	var wagon_count: int = wagons_container.get_child_count()
	if wagon_count <= 0:
		return

	for i in range(wagon_count - 1):
		var left_wagon := wagons_container.get_child(i) as Node2D
		var right_wagon := wagons_container.get_child(i + 1) as Node2D
		if left_wagon == null or right_wagon == null:
			continue

		var left_roof := left_wagon.get_node_or_null("RoofMarker") as Marker2D
		var right_roof := right_wagon.get_node_or_null("RoofMarker") as Marker2D
		var left_inside := left_wagon.get_node_or_null("InteriorEntry") as Marker2D
		if left_roof == null or right_roof == null or left_inside == null:
			continue

		var ladder_top_y: float = minf(left_roof.global_position.y, right_roof.global_position.y)
		var ladder_bottom_y: float = left_inside.global_position.y
		var ladder_center_x: float = (left_roof.global_position.x + right_roof.global_position.x) * 0.5
		_create_ladder_area(Vector2(ladder_center_x, (ladder_top_y + ladder_bottom_y) * 0.5), absf(ladder_bottom_y - ladder_top_y) + LADDER_EXTRA_HEIGHT)

	if wagon_count == 1:
		var single_wagon := wagons_container.get_child(0) as Node2D
		if single_wagon == null:
			return
		var roof_marker := single_wagon.get_node_or_null("RoofMarker") as Marker2D
		var inside_marker := single_wagon.get_node_or_null("InteriorEntry") as Marker2D
		if roof_marker == null or inside_marker == null:
			return
		_create_ladder_area(Vector2(inside_marker.global_position.x, (roof_marker.global_position.y + inside_marker.global_position.y) * 0.5), absf(inside_marker.global_position.y - roof_marker.global_position.y) + LADDER_EXTRA_HEIGHT)

func _create_ladder_area(global_center: Vector2, height: float) -> void:
	if ladders_container == null:
		return

	var ladder_area := Area2D.new()
	ladder_area.name = "LadderArea"
	ladder_area.collision_layer = LADDER_LAYER_BIT
	ladder_area.collision_mask = 0
	ladder_area.add_to_group("ladder")

	var ladder_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(LADDER_WIDTH, maxf(24.0, height))
	ladder_shape.shape = rect_shape
	ladder_area.add_child(ladder_shape)

	ladders_container.add_child(ladder_area)
	ladder_area.global_position = global_center
