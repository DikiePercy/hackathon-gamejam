extends Node

func run_tests() -> Array:
	return [
		_make_result("MainPerson initial ammo", _test_initial_ammo()),
		_make_result("MainPerson shoot decrements clip", _test_shoot_decrements_clip()),
		_make_result("MainPerson reload starts when empty", _test_reload_when_empty()),
		_make_result("MainPerson finish reload", _test_finish_reload())
	]

func _make_result(test_name: String, passed: bool, message: String = "") -> Dictionary:
	return {"name": test_name, "passed": passed, "message": message}

const WEAPON_READY := 0
const WEAPON_RELOADING := 1

func _test_initial_ammo() -> bool:
	var player = MainPerson.new()
	player.bullet_scene = load("res://tests/dummy_bullet.tscn")
	return player._ammo_in_clip == player.clip_size and player._reloads_left == player.reloads_count and player._weapon_state == WEAPON_READY

func _test_shoot_decrements_clip() -> bool:
	var player = MainPerson.new()
	player.bullet_scene = load("res://tests/dummy_bullet.tscn")
	player._weapon_state = WEAPON_READY
	player._shoot_timer = 0.0
	player._try_shoot()
	return player._ammo_in_clip == player.clip_size - 1 and player._shoot_timer == player.SHOOT_COOLDOWN

func _test_reload_when_empty() -> bool:
	var player = MainPerson.new()
	player.bullet_scene = load("res://tests/dummy_bullet.tscn")
	player._ammo_in_clip = 0
	player._weapon_state = WEAPON_READY
	player._reloads_left = 2
	player._try_shoot()
	return player._weapon_state == WEAPON_RELOADING and player._reload_timer == player.reload_time

func _test_finish_reload() -> bool:
	var player = MainPerson.new()
	player._ammo_in_clip = 0
	player._weapon_state = WEAPON_RELOADING
	player._reloads_left = 2
	player._finish_reload()
	return player._ammo_in_clip == player.clip_size and player._reloads_left == 1 and player._weapon_state == WEAPON_READY
