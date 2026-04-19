extends Node2D

const LOBBY_PORT := 30123
const MAX_PLAYERS := 2
const GAME_SCENE := "res://scenes/multiplayer/game.tscn"

var _ip_display: Label
var _ip_input: LineEdit
var _status_label: Label
var _host_button: Button
var _join_button: Button

func _ready() -> void:
	if get_tree().get_multiplayer().multiplayer_peer != null:
		get_tree().get_multiplayer().multiplayer_peer = null

	# Ищем ноды по старым путям из твоей сцены
	_ip_input = get_node_or_null("CanvasLayer/Panel/VBoxContainer/IPRow/IPInput")
	_status_label = get_node_or_null("CanvasLayer/Panel/VBoxContainer/StatusLabel")
	_host_button = get_node_or_null("CanvasLayer/Panel/VBoxContainer/HostButton")
	_join_button = get_node_or_null("CanvasLayer/Panel/VBoxContainer/IPRow/JoinButton")

	# IPDisplay — новая нода, ищем или используем StatusLabel
	_ip_display = get_node_or_null("CanvasLayer/Panel/VBoxContainer/IPDisplay")
	if _ip_display == null:
		_ip_display = _status_label  # fallback на статус

	if _ip_display:
		_ip_display.text = "Ваш IP: %s" % _get_local_ip()

	if _host_button:
		_host_button.connect("pressed", _on_host_pressed)
	if _join_button:
		_join_button.connect("pressed", _on_join_pressed)

func _get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	return "127.0.0.1"

func _on_host_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(LOBBY_PORT, MAX_PLAYERS)
	if err != OK:
		if _status_label:
			_status_label.text = "Ошибка: %d" % err
		return
	get_tree().get_multiplayer().multiplayer_peer = peer
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	var address = ""
	if _ip_input:
		address = _ip_input.text.strip_edges()
	if address == "":
		if _status_label:
			_status_label.text = "Введите IP!"
		return

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, LOBBY_PORT)
	if err != OK:
		if _status_label:
			_status_label.text = "Ошибка: %d" % err
		return

	get_tree().get_multiplayer().multiplayer_peer = peer

	var api = get_tree().get_multiplayer()
	api.connect("connected_to_server", _on_connected)
	api.connect("connection_failed", _on_failed)

	if _status_label:
		_status_label.text = "Подключение к %s..." % address

func _on_connected() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_failed() -> void:
	if _status_label:
		_status_label.text = "Не удалось подключиться"
	get_tree().get_multiplayer().multiplayer_peer = null
