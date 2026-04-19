# res://scenes/main/main.gd
extends Node2D

@onready var _player: MainPerson = $Player

var _death_screen_layer: CanvasLayer = null
var _death_flow_started: bool = false

func _ready() -> void:
	_apply_pending_load()
	if _player != null:
		_player.died.connect(_on_player_died)

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
	
