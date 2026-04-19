extends Node

var test_paths = [
	"res://tests/test_main_person.gd",
	"res://tests/test_enemy.gd",
	"res://tests/test_game_manager.gd"
]

func _ready() -> void:
	var total := 0
	var failed := 0
	for path in test_paths:
		var script = load(path)
		if script == null:
			print("ERROR: Не удалось загрузить тестовый скрипт: ", path)
			continue
		var test_node = script.instantiate()
		add_child(test_node)
		if test_node.has_method("run_tests"):
			for result in test_node.run_tests():
				total += 1
				if result.passed:
					print("PASS: ", result.name)
				else:
					print("FAIL: ", result.name, " — ", result.message)
					failed += 1
		else:
			print("ERROR: Test script has no run_tests(): ", script)
		test_node.queue_free()

	print("=== TESTS COMPLETE ===")
	print("Total:", total, "Passed:", total - failed, "Failed:", failed)
	if failed > 0:
		print("Some tests failed. Check the output above.")
	else:
		print("All tests passed.")
	get_tree().quit()
