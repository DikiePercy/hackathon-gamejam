# res://scenes/menu/node_2d.gd
extends Node2D

@onready var _menu_music: AudioStreamPlayer = $MenuMusic
@onready var _main_panel: Panel = $Panel
@onready var _save_panel: Panel = $SavePanel
@onready var _save_list: ItemList = $SavePanel/VBoxContainer/SaveList
@onready var _save_title: Label = $SavePanel/VBoxContainer/Title

var _menu_music_restart_timer := 60.0
var _open_mode: String = "play"

const SAVE_DIR_PATH := "user://saves"
const DEFAULT_MAIN_SCENE := "res://scenes/main/main.tscn"

func _ready() -> void:
	_menu_music.play()
	_menu_music.finished.connect(_on_menu_music_finished)
	_layout_save_panel()
	_save_panel.hide()
	_ensure_save_dir()

func _process(delta: float) -> void:
	_menu_music_restart_timer -= delta
	if _menu_music_restart_timer <= 0.0:
		_menu_music_restart_timer += 60.0
		if _menu_music != null:
			_menu_music.play()

func _on_menu_music_finished() -> void:
	_menu_music.play()

func _on_quit_pressed():
	GameManager.autosave_current_state()
	get_tree().quit()

func _on_play_pressed():
	_on_new_save_pressed()

func _on_load_pressed() -> void:
	_open_save_menu("load")

func _on_new_save_pressed() -> void:
	GameManager.reset_to_defaults()
	var slot_id := _new_slot_id()
	GameManager.current_save_slot_id = slot_id

	var payload := {
		"meta": {
			"slot_id": slot_id,
			"saved_at_text": Time.get_datetime_string_from_system().replace("T", " "),
			"saved_at_unix": int(Time.get_unix_time_from_system())
		},
		"game_manager": GameManager.to_save_dict(),
		"scene_path": DEFAULT_MAIN_SCENE
	}

	if not _write_slot(slot_id, payload):
		push_warning("Failed to create new save")
		return

	GameManager.pending_load_data = payload
	get_tree().change_scene_to_file(DEFAULT_MAIN_SCENE)

func _on_load_selected_pressed() -> void:
	_load_selected_slot()

func _on_save_list_item_activated(_index: int) -> void:
	_load_selected_slot()

func _on_save_menu_back_pressed() -> void:
	_save_panel.hide()
	_main_panel.show()

func _on_depot_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/depot/depot.tscn")

func _open_save_menu(mode: String) -> void:
	_open_mode = mode
	_save_title.text = "Choose Save (%s)" % mode.capitalize()
	_layout_save_panel()
	_main_panel.hide()
	_save_panel.show()
	_refresh_save_list()

func _layout_save_panel() -> void:
	var viewport_size := get_viewport_rect().size
	# Base game viewport is 480x270 (scaled up), so the panel must fit this space.
	var panel_size := viewport_size - Vector2(24, 20)
	panel_size.x = clampf(panel_size.x, 320.0, 456.0)
	panel_size.y = clampf(panel_size.y, 180.0, 250.0)
	_save_panel.size = panel_size
	_save_panel.position = (viewport_size - panel_size) * 0.5

func _refresh_save_list() -> void:
	_save_list.clear()
	for slot in _read_slots_sorted():
		var slot_id := String(slot.get("slot_id", ""))
		var saved_at := String(slot.get("saved_at_text", "unknown time"))
		var label := "%s  |  %s" % [slot_id, saved_at]
		_save_list.add_item(label)
		_save_list.set_item_metadata(_save_list.item_count - 1, slot_id)

func _load_selected_slot() -> void:
	if _save_list.get_selected_items().is_empty():
		return

	var selected := _save_list.get_selected_items()[0]
	var slot_id = _save_list.get_item_metadata(selected)
	if slot_id == null:
		return

	var save_path := _slot_path(String(slot_id))
	if not FileAccess.file_exists(save_path):
		push_warning("Selected save not found")
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Cannot open selected save")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not (parsed is Dictionary):
		push_warning("Selected save is invalid")
		return

	var payload: Dictionary = parsed
	GameManager.current_save_slot_id = String(slot_id)
	GameManager.pending_load_data = payload

	var scene_path := String(payload.get("scene_path", DEFAULT_MAIN_SCENE))
	get_tree().change_scene_to_file(scene_path)

func _read_slots_sorted() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR_PATH)
	if dir == null:
		return out

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir() or not file_name.ends_with(".json"):
			continue

		var path := _slot_path(file_name.trim_suffix(".json"))
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed == null or not (parsed is Dictionary):
			continue

		var payload: Dictionary = parsed
		var meta = payload.get("meta", {})
		if meta is Dictionary:
			var slot: Dictionary = meta
			if not slot.has("slot_id"):
				slot["slot_id"] = file_name.trim_suffix(".json")
			if not slot.has("saved_at_unix"):
				slot["saved_at_unix"] = 0
			if not slot.has("saved_at_text"):
				slot["saved_at_text"] = "unknown time"
			out.append(slot)

	out.sort_custom(func(a: Dictionary, b: Dictionary):
		return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
	)
	return out

func _write_slot(slot_id: String, payload: Dictionary) -> bool:
	_ensure_save_dir()
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR_PATH)

func _new_slot_id() -> String:
	return "save_%d" % int(Time.get_unix_time_from_system())

func _slot_path(slot_id: String) -> String:
	return SAVE_DIR_PATH.path_join("%s.json" % slot_id)
