extends Node

func run_tests() -> Array:
	return [
		_make_result("Enemy reload starts when out of ammo", _test_enemy_reload_start()),
		_make_result("Enemy knife mode after no reloads", _test_enemy_switches_to_knife())
	]

func _make_result(test_name: String, passed: bool, message: String = "") -> Dictionary:
	return {"name": test_name, "passed": passed, "message": message}

const ENEMY_WEAPON_RELOADING := 2
const ENEMY_WEAPON_KNIFE := 3

func _test_enemy_reload_start() -> bool:
	var enemy_script = load("res://scenes/characters/enemy.gd")
	var enemy = enemy_script.instantiate()
	enemy.bullet_scene = load("res://tests/dummy_bullet.tscn")
	enemy._ammo_in_clip = 0
	var target = MainPerson.new()
	target.global_position = Vector2(100, 0)
	enemy._try_shoot_at(target)
	return enemy._weapon_state == ENEMY_WEAPON_RELOADING and enemy._reload_timer == enemy.reload_time

func _test_enemy_switches_to_knife() -> bool:
	var enemy_script = load("res://scenes/characters/enemy.gd")
	var enemy = enemy_script.instantiate()
	enemy.bullet_scene = load("res://tests/dummy_bullet.tscn")
	enemy._ammo_in_clip = 0
	enemy._reloads_left = 0
	var target = MainPerson.new()
	target.global_position = Vector2(100, 0)
	enemy._try_shoot_at(target)
	return enemy._weapon_state == ENEMY_WEAPON_KNIFE
