# res://scenes/main/main.gd
extends Node2D

enum MissionState {
	IN_PROGRESS,
	SUCCESS,
	FAIL
}

@onready var _player: MainPerson = $Player
@onready var _train: Node2D = $Train
@onready var _depot_button: Button = $CanvasLayer/Button

var _death_screen_layer: CanvasLayer = null
var _death_flow_started: bool = false
var _mission_state: MissionState = MissionState.IN_PROGRESS
var _mission_timer: float = 0.0
var _mission_progress: float = 0.0
var _mission_target_distance: float = 0.0
var _mission_end_started: bool = false

var _mission_ui_layer: CanvasLayer = null
var _mission_status_label: Label = null
var _mission_timer_label: Label = null
var _mission_passengers_label: Label = null
var _mission_integrity_label: Label = null
var _mission_progress_label: Label = null

func _ready() -> void:
	_apply_pending_load()
	GameManager.begin_mission_run()
	_mission_timer = maxf(GameManager.mission_time_limit, 20.0)
	_mission_target_distance = maxf(GameManager.mission_target_distance, 200.0)
	_setup_mission_ui()
	_refresh_mission_ui()

	if _train != null:
		if _train.has_signal("go_trein") and not _train.go_trein.is_connected(_on_train_started):
			_train.go_trein.connect(_on_train_started)
		if _train.has_signal("stop_trein") and not _train.stop_trein.is_connected(_stop_train_started):
			_train.stop_trein.connect(_stop_train_started)
		if _train.has_signal("train_objective_broken") and not _train.train_objective_broken.is_connected(_on_train_objective_broken):
			_train.train_objective_broken.connect(_on_train_objective_broken)

	if _player != null:
		_player.died.connect(_on_player_died)
	if _depot_button != null:
		_depot_button.hide()

func _process(delta: float) -> void:
	if _mission_state != MissionState.IN_PROGRESS:
		return
	if _death_flow_started:
		return

	_mission_timer = maxf(_mission_timer - delta, 0.0)
	_mission_progress += maxf(float(GameManager.train_speed), 0.0) * delta
	_evaluate_mission_state()
	_refresh_mission_ui()

func _apply_pending_load() -> void:
	if GameManager.pending_load_data.is_empty():
		return

	var data := GameManager.pending_load_data
	GameManager.pending_load_data = {}

	if data.has("game_manager") and data["game_manager"] is Dictionary:
		GameManager.apply_save_dict(data["game_manager"])

	if _player != null and data.has("player") and data["player"] is Dictionary:
		var player_data: Dictionary = data["player"]
		var pos_x := float(player_data.get("position_x", _player.global_position.x))
		var pos_y := float(player_data.get("position_y", _player.global_position.y))
		_player.global_position = Vector2(pos_x, pos_y)

		_player.max_health = int(player_data.get("max_health", _player.max_health))
		_player.health = clampi(int(player_data.get("health", _player.health)), 0, _player.max_health)
		_player.health_changed.emit(_player.health)

func _evaluate_mission_state() -> void:
	var alive_passengers := _get_alive_passenger_count()
	var train_integrity := _get_train_integrity()
	var reached_target := _mission_progress >= _mission_target_distance

	if alive_passengers <= 0:
		_finish_mission(false, "All passengers lost")
		return
	if train_integrity <= 0:
		_finish_mission(false, "Train destroyed")
		return

	if reached_target:
		_finish_mission(true, "Destination reached")
		return

	if _mission_timer <= 0.0:
		_finish_mission(false, "Time is up")

func _get_alive_passenger_count() -> int:
	if _train != null and _train.has_method("get_total_alive_passengers"):
		return int(_train.call("get_total_alive_passengers"))
	return get_tree().get_nodes_in_group("passenger").size()

func _get_train_integrity() -> int:
	if _train != null and _train.has_method("get_train_integrity"):
		return int(_train.call("get_train_integrity"))
	return GameManager.train_integrity_current

func _on_player_died() -> void:
	if _death_flow_started:
		return
	_death_flow_started = true

	_show_wasted_overlay()
	await get_tree().create_timer(2.2).timeout

	if GameManager.load_latest_save_into_pending():
		var payload := GameManager.pending_load_data
		var scene_path := String(payload.get("scene_path", get_tree().current_scene.scene_file_path))
		get_tree().change_scene_to_file(scene_path)
		return

	get_tree().reload_current_scene()

func _show_wasted_overlay() -> void:
	if _death_screen_layer != null and is_instance_valid(_death_screen_layer):
		return

	_death_screen_layer = CanvasLayer.new()
	_death_screen_layer.layer = 100
	add_child(_death_screen_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_screen_layer.add_child(shade)

	var wasted_label := Label.new()
	wasted_label.text = "ПОТРАЧЕНО"
	wasted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wasted_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wasted_label.add_theme_font_size_override("font_size", 44)
	wasted_label.modulate = Color(0.95, 0.15, 0.15, 1.0)
	wasted_label.set_anchors_preset(Control.PRESET_CENTER)
	wasted_label.position = Vector2(-180.0, -28.0)
	wasted_label.size = Vector2(360.0, 56.0)
	wasted_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_screen_layer.add_child(wasted_label)

func _on_train_started():
	if _depot_button != null:
		_depot_button.hide()
	
func _stop_train_started() -> void:
	if _depot_button != null:
		_depot_button.show()

func _on_train_objective_broken() -> void:
	_finish_mission(false, "Train objective broken")

func _finish_mission(success: bool, reason: String) -> void:
	if _mission_end_started or _death_flow_started:
		return
	_mission_end_started = true
	_mission_state = MissionState.SUCCESS if success else MissionState.FAIL

	var alive_passengers := _get_alive_passenger_count()
	var ratio := _mission_progress / _mission_target_distance
	var result := GameManager.apply_mission_result(success, alive_passengers, _mission_timer, ratio)
	_show_mission_result_overlay(success, reason, result)

	await get_tree().create_timer(2.6).timeout
	GameManager.autosave_current_state()
	get_tree().change_scene_to_file("res://scenes/depot/depot.tscn")

func _setup_mission_ui() -> void:
	if _mission_ui_layer != null and is_instance_valid(_mission_ui_layer):
		return

	_mission_ui_layer = CanvasLayer.new()
	_mission_ui_layer.layer = 20
	add_child(_mission_ui_layer)

	_mission_status_label = Label.new()
	_mission_status_label.text = "RUN: IN PROGRESS"
	_mission_status_label.position = Vector2(12.0, 10.0)
	_mission_ui_layer.add_child(_mission_status_label)

	_mission_timer_label = Label.new()
	_mission_timer_label.position = Vector2(12.0, 30.0)
	_mission_ui_layer.add_child(_mission_timer_label)

	_mission_passengers_label = Label.new()
	_mission_passengers_label.position = Vector2(12.0, 50.0)
	_mission_ui_layer.add_child(_mission_passengers_label)

	_mission_integrity_label = Label.new()
	_mission_integrity_label.position = Vector2(12.0, 70.0)
	_mission_ui_layer.add_child(_mission_integrity_label)

	_mission_progress_label = Label.new()
	_mission_progress_label.position = Vector2(12.0, 90.0)
	_mission_ui_layer.add_child(_mission_progress_label)

func _refresh_mission_ui() -> void:
	if _mission_timer_label == null:
		return

	var alive_passengers := _get_alive_passenger_count()
	var train_integrity := _get_train_integrity()
	var remaining_distance := maxf(_mission_target_distance - _mission_progress, 0.0)

	_mission_timer_label.text = "Time: %.1f s" % _mission_timer
	_mission_passengers_label.text = "Passengers alive: %d" % alive_passengers
	_mission_integrity_label.text = "Train integrity: %d" % train_integrity
	_mission_progress_label.text = "Distance left: %.0f" % remaining_distance

func _show_mission_result_overlay(success: bool, reason: String, result: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.56)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(-180.0, -45.0)
	title.size = Vector2(360.0, 54.0)
	title.add_theme_font_size_override("font_size", 36)
	title.text = "RUN SUCCESS" if success else "RUN FAILED"
	title.modulate = Color(0.3, 0.95, 0.35, 1.0) if success else Color(0.95, 0.25, 0.25, 1.0)
	layer.add_child(title)

	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.set_anchors_preset(Control.PRESET_CENTER)
	summary.position = Vector2(-210.0, 8.0)
	summary.size = Vector2(420.0, 80.0)
	var reward := int(result.get("reward", 0))
	summary.text = "%s\nReward: %d" % [reason, reward]
	layer.add_child(summary)

func _on_button_pressed() -> void:
	GameManager.autosave_current_state()
	get_tree().change_scene_to_file("res://scenes/depot/depot.tscn")
