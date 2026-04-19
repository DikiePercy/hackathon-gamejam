extends Node2D

const PLAYER_SCENE := preload("res://scenes/multiplayer/MultiplayerPawn.tscn")
const BULLET_SCENE := preload("res://scenes/characters/Bullet.tscn")

@onready var _status_label: Label = $CanvasLayer/StatusLabel
@onready var _hit_label: Label = $CanvasLayer/HitLabel
@onready var _back_button: Button = $CanvasLayer/BackButton
@onready var _local_spawn: Marker2D = $LocalSpawn
@onready var _remote_spawn: Marker2D = $RemoteSpawn

var _local_player: MultiplayerPawn = null
var _remote_player: MultiplayerPawn = null
var _local_peer_id: int = 0
var _local_hits: int = 0

func _ready() -> void:
	if get_tree().get_multiplayer().multiplayer_peer == null:
		_status_label.text = "Нет подключения"
		return

	_local_peer_id = get_tree().get_multiplayer().get_unique_id()

	get_tree().get_multiplayer().connect("peer_connected", _on_peer_connected)
	get_tree().get_multiplayer().connect("peer_disconnected", _on_peer_disconnected)

	if _back_button:
		_back_button.connect("pressed", _on_back_pressed)

	_spawn_players()

	var my_ip = _get_local_ip()
	_status_label.text = "ID: %d | IP: %s" % [_local_peer_id, my_ip]
	_update_hit_label()

func _get_local_ip() -> String:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	return "127.0.0.1"

func _spawn_players() -> void:
	var is_host = (_local_peer_id == 1)

	_local_player = PLAYER_SCENE.instantiate()
	_local_player.name = "LocalPlayer"
	_local_player.position = _local_spawn.position if is_host else _remote_spawn.position
	_local_player.is_local = true
	_local_player.connect("shot_fired", _on_local_shot)
	add_child(_local_player)

	_remote_player = PLAYER_SCENE.instantiate()
	_remote_player.name = "RemotePlayer"
	_remote_player.position = _remote_spawn.position if is_host else _local_spawn.position
	_remote_player.is_local = false
	add_child(_remote_player)

func _on_local_shot(origin: Vector2, direction: Vector2) -> void:
	_spawn_bullet(origin, direction, true)
	rpc("rpc_spawn_bullet", origin, direction)

func _spawn_bullet(origin: Vector2, direction: Vector2, is_mine: bool) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = direction
	bullet.global_position = origin
	bullet.body_entered.connect(func(body):
		if not is_mine:
			return
		if body == _remote_player:
			_local_hits += 1
			_update_hit_label()
			rpc("rpc_take_damage", 25)
	)
	add_child(bullet)

@rpc("any_peer", "reliable")
func rpc_take_damage(amount: int) -> void:
	if _local_player and _local_player.has_method("take_damage"):
		_local_player.take_damage(amount)
		_status_label.text = "HP: %d" % _local_player._hp
