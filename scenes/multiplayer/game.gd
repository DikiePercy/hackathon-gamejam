extends Node2D

const PLAYER_SCENE := preload("res://scenes/multiplayer/MultiplayerPawn.tscn")
const BULLET_SCENE := preload("res://scenes/characters/Bullet.tscn")

@onready var _status_label: Label = $CanvasLayer/StatusLabel
@onready var _hit_label: Label = $CanvasLayer/HitLabel
@onready var _instructions_label: Label = $CanvasLayer/InstructionsLabel
@onready var _back_button: Button = $CanvasLayer/BackButton
@onready var _local_spawn: Position2D = $LocalSpawn
@onready var _remote_spawn: Position2D = $RemoteSpawn

var _local_player: Node = null
var _remote_player: Node = null
var _local_peer_id: int = 0
var _local_hits: int = 0

func _ready() -> void:
	if get_tree().multiplayer.network_peer == null:
		_status_label.text = "Нет сетевого подключения"
		return

	_local_peer_id = get_tree().multiplayer.peer_id
	_spawn_players()
	get_tree().multiplayer.connect("peer_connected", callable(self, "_on_peer_connected"))
	get_tree().multiplayer.connect("peer_disconnected", callable(self, "_on_peer_disconnected"))
	_status_label.text = "Сетевой режим: ваш ID %d" % _local_peer_id
	_update_hit_label()

func _spawn_players() -> void:
	_local_player = PLAYER_SCENE.instantiate()
	_local_player.name = "LocalPlayer"
	_local_player.position = _local_spawn.global_position
	_local_player.is_local = true
	_local_player.set_physics_process(true)
	_local_player.set_process(true)
	_local_player.connect("shot_fired", callable(self, "_on_player_shot"))
	add_child(_local_player)

	_remote_player = PLAYER_SCENE.instantiate()
	_remote_player.name = "RemotePlayer"
	_remote_player.position = _remote_spawn.global_position
	_remote_player.is_local = false
	_remote_player.set_physics_process(false)
	_remote_player.set_process(false)
	add_child(_remote_player)

func _on_player_shot(origin: Vector2, direction: Vector2) -> void:
	_spawn_bullet(_local_peer_id, origin, direction)
	rpc_unreliable("rpc_spawn_bullet", _local_peer_id, origin, direction)

func _spawn_bullet(owner_id: int, origin: Vector2, direction: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.owner_peer_id = owner_id
	bullet.direction = direction
	bullet.global_position = origin
	bullet.body_entered.connect(callable(self, "_on_bullet_body_entered"), [owner_id])
	add_child(bullet)

func _on_bullet_body_entered(body: Node, owner_id: int) -> void:
	if owner_id != _local_peer_id:
		return
	if body == _local_player:
		return
	if body == _remote_player:
		_local_hits += 1
		_update_hit_label()

func _update_hit_label() -> void:
	_hit_label.text = "Ваши попадания: %d" % _local_hits

func _on_peer_connected(id: int) -> void:
	_status_label.text = "Игрок %d подключился" % id

func _on_peer_disconnected(id: int) -> void:
	_status_label.text = "Игрок %d отключился" % id

@rpc("any_peer")
func rpc_spawn_bullet(owner_id: int, origin: Vector2, direction: Vector2) -> void:
	if owner_id == _local_peer_id:
		return
	_spawn_bullet(owner_id, origin, direction)

@rpc("any_peer")
func rpc_update_player_state(peer_id: int, position: Vector2, facing_right: bool, aim_direction: Vector2) -> void:
	if peer_id == _local_peer_id:
		return
	if _remote_player:
		_remote_player.set_remote_state(position, facing_right, aim_direction)

func _physics_process(delta: float) -> void:
	if _local_player == null:
		return
	if _remote_player == null:
		return
	if _local_player.has_method("get_network_state"):
		var state = _local_player.get_network_state()
		rpc_unreliable("rpc_update_player_state", _local_peer_id, state.position, state.facing_right, state.aim_direction)

func _on_back_pressed() -> void:
	if get_tree().multiplayer.network_peer != null:
		get_tree().multiplayer.network_peer.close_connection()
	get_tree().change_scene_to_file("res://scenes/menu/node_2d.tscn")
