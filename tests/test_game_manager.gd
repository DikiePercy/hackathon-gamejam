extends Node

func run_tests() -> Array:
	return [
		_make_result("GameManager shotgun purchase state", _test_shotgun_state()),
		_make_result("GameManager gold is mutable", _test_total_gold()),
	]

func _make_result(test_name: String, passed: bool, message: String = "") -> Dictionary:
	return {"name": test_name, "passed": passed, "message": message}

const MAINPERSON_WEAPON_PISTOL := 0
const MAINPERSON_WEAPON_SHOTGUN := 1

func _test_shotgun_state() -> bool:
	GameManager.has_shotgun = false
	var player = MainPerson.new()
	player._update_weapon_from_game_manager()
	var result = player._weapon_type == MAINPERSON_WEAPON_PISTOL
	GameManager.has_shotgun = true
	player._update_weapon_from_game_manager()
	return result and player._weapon_type == MAINPERSON_WEAPON_SHOTGUN

func _test_total_gold() -> bool:
	var before = GameManager.total_gold
	GameManager.total_gold += 123
	var result = GameManager.total_gold == before + 123
	GameManager.total_gold = before
	return result
