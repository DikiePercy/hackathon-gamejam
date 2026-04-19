extends Node2D

const LOBBY_PORT := 30123
const MAX_PLAYERS := 2
const GAME_SCENE := "res://scenes/multiplayer/game.tscn"

var _ip_input: LineEdit
var _status_label: Label
var _players_list: VBoxContainer
var _ready_button: Button
var _start_button: Button
var _host_button: Button
var _join_button: Button

var _is_host: bool = false
var _local_peer_id: int = 0
var _local_name: String = "Игрок"
var _is_ready: bool = false
var _players: Dictionary = {}

func _ready() -> void:
	_ip_input = _find_ui_node("CanvasLayer/Panel/VBoxContainer/IPRow/IPInput")
	_status_label = _find_ui_node("CanvasLayer/Panel/VBoxContainer/StatusLabel")
	_players_list = _find_ui_node("CanvasLayer/Panel/VBoxContainer/PlayersList")
	_ready_button = _find_ui_node("CanvasLayer/Panel/VBoxContainer/ReadyButton")
	_start_button = _find_ui_node("CanvasLayer/Panel/VBoxContainer/StartButton")
	_host_button = _find_ui_node("CanvasLayer/Panel/VBoxContainer/HostButton")
	_join_button = _find_ui_node("CanvasLayer/Panel/VBoxContainer/IPRow/JoinButton")

	if _ip_input:
		_ip_input.text = "127.0.0.1"
	if _status_label:
		_status_label.text = "Не подключено"
	if _ready_button:
		_ready_button.disabled = true
	if _start_button:
		_start_button.disabled = true

	if _host_button:
		_host_button.connect("pressed", Callable(self, "_on_host_pressed"))
	if _join_button:
		_join_button.connect("pressed", Callable(self, "_on_join_pressed"))
	if _ready_button:
		_ready_button.connect("pressed", Callable(self, "_on_ready_pressed"))
	if _start_button:
		_start_button.connect("pressed", Callable(self, "_on_start_pressed"))

	_local_name = "Игрок"
	_players.clear()
	_refresh_player_list()

func _on_host_pressed() -> void:
	print("Lobby: _on_host_pressed called")
	if get_tree().multiplayer.network_peer != null:
		_set_status("Сервер уже запущен или подключен")
		return

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(LOBBY_PORT, MAX_PLAYERS)
	print("Lobby: create_server returned", err)
	if err != OK:
		_set_status("Не удалось запустить сервер: %d" % err)
		return
	get_tree().multiplayer.network_peer = peer

	_setup_multiplayer(peer)
	_is_host = true
	_local_peer_id = get_tree().multiplayer.peer_id
	_players[_local_peer_id] = {"name": _local_name + " (хост)", "ready": false}
	if _host_button:
		_host_button.disabled = true
	if _join_button:
		_join_button.disabled = true
	if _ready_button:
		_ready_button.disabled = false
	if _start_button:
		_start_button.disabled = true
	if _ip_input:
		_ip_input.editable = false
	_set_status("Сервер запущен на порту %d. Ожидание игроков..." % LOBBY_PORT)
	_refresh_player_list()

func _on_join_pressed() -> void:
	if get_tree().multiplayer.network_peer != null:
		return

	var address = ""
	if _ip_input:
		address = _ip_input.text.strip_edges()
	if address == "":
		address = "127.0.0.1"

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, LOBBY_PORT)
	if err != OK:
		_set_status("Не удалось подключиться: %d" % err)
		return
	get_tree().multiplayer.network_peer = peer

	_setup_multiplayer(peer)
	if _host_button:
		_host_button.disabled = true
	if _ip_input:
		_ip_input.editable = false
	_set_status("Подключение к %s:%d..." % [address, LOBBY_PORT])

func _setup_multiplayer(peer: ENetMultiplayerPeer) -> void:
	var api = get_tree().multiplayer
	api.connect("peer_connected", Callable(self, "_on_peer_connected"))
	api.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
	peer.connect("connection_succeeded", Callable(self, "_on_connection_succeeded"))
	peer.connect("connection_failed", Callable(self, "_on_connection_failed"))
	peer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))

func _on_connection_succeeded() -> void:
	_local_peer_id = get_tree().multiplayer.peer_id
	_players[_local_peer_id] = {"name": _local_name, "ready": false}
	if _ready_button:
		_ready_button.disabled = false
	if _status_label:
		_status_label.text = "Подключено к серверу"
	rpc_id(1, "rpc_register_player", _local_peer_id, _local_name, _is_ready)

func _on_connection_failed() -> void:
	_set_status("Не удалось подключиться")
	_reset_network()

func _on_server_disconnected() -> void:
	_set_status("Отключено от сервера")
	_reset_network()

func _on_peer_connected(id: int) -> void:
	if not _is_host:
		return

	_players[id] = {"name": "Игрок %d" % id, "ready": false}
	rpc_id(id, "rpc_sync_full_lobby", _players)
	rpc_id(id, "rpc_register_player", _local_peer_id, _local_name, _is_ready)
	_set_status("Игрок %d подключился" % id)
	_refresh_player_list()
	_refresh_start_button()

func _on_peer_disconnected(id: int) -> void:
	_players.erase(id)
	_set_status("Игрок %d отключился" % id)
	_refresh_player_list()
	_refresh_start_button()

func _on_ready_pressed() -> void:
	_is_ready = !_is_ready
	if _ready_button:
		_ready_button.text = "Отменить готовность" if _is_ready else "Готов"
	if _players.has(_local_peer_id):
		_players[_local_peer_id].ready = _is_ready
	rpc("rpc_update_player_ready", _local_peer_id, _is_ready)
	_refresh_player_list()
	_refresh_start_button()

func _on_start_pressed() -> void:
	if not _is_host:
		return
	if not _can_start():
		return
	rpc("rpc_start_game")

func _can_start() -> bool:
	if _players.size() < 2:
		return false
	for player_data in _players.values():
		if not player_data.ready:
			return false
	return true

func _refresh_start_button() -> void:
	if _start_button:
		_start_button.disabled = not (_is_host and _can_start())

func _refresh_player_list() -> void:
	if _players_list == null:
		return
	for child in _players_list.get_children():
		child.queue_free()

	var peer_ids = _players.keys()
	peer_ids.sort()
	for peer_id in peer_ids:
		var data = _players[peer_id]
		var ready_text = "✔" if data.ready else "✖"
		var label = Label.new()
		label.text = "%s %s" % [ready_text, data.name]
		_players_list.add_child(label)

func _update_status(text: String) -> void:
	_set_status(text)

func _set_status(text: String) -> void:
	print("Lobby status:", text)
	if _status_label:
		_status_label.text = text
	else:
		push_warning("Lobby: status label is null")

func _reset_network() -> void:
	if get_tree().multiplayer.network_peer != null:
		get_tree().multiplayer.network_peer.close_connection()
	get_tree().multiplayer.network_peer = null
	_is_host = false
	_local_peer_id = 0
	_is_ready = false
	_players.clear()
	if _ready_button:
		_ready_button.disabled = true
	if _start_button:
		_start_button.disabled = true
	_refresh_player_list()

func _find_ui_node(path: String) -> Node:
	var node: Node = get_node_or_null(path)
	if node == null:
		push_error("Lobby: UI node not found: %s" % path)
	return node

@rpc("any_peer")
func rpc_sync_full_lobby(players: Dictionary) -> void:
	_players = players.duplicate(true)
	_refresh_player_list()
	_refresh_start_button()

@rpc("any_peer")
func rpc_register_player(peer_id: int, player_name: String, is_ready: bool) -> void:
	_players[peer_id] = {"name": player_name, "ready": is_ready}
	_refresh_player_list()
	_refresh_start_button()

@rpc("any_peer")
func rpc_update_player_ready(peer_id: int, is_ready: bool) -> void:
	if _players.has(peer_id):
		_players[peer_id].ready = is_ready
		_refresh_player_list()
		_refresh_start_button()

@rpc("any_peer")
func rpc_start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
