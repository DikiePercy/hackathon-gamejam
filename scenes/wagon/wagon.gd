extends Node2D

# Текущий уровень вагона (1, 2 или 3)
var wagon_level = 1
var passengers = 0
var is_in_depot = false
var vagon_type = 1


# Настройки доходности для каждого уровня
var money_per_level = {
	1: 10,  # Обычные работяги
	2: 50,  # Торговцы
	3: 100  # Аристократы
}

# Ссылка на спрайт, чтобы менять вид вагона
@onready var sprite = $StaticBody2D/AnimatedSprite2D

func _ready():
	update_wagon_stats()
	sprite.play("v" + str(vagon_type))
	

# Функция для повышения уровня вагона
func upgrade_wagon():
	if wagon_level < 3:
		wagon_level += 1
		update_wagon_stats()
		return true # Улучшение успешно
	return false # Максимальный уровень уже достигнут

# Обновляем характеристики и внешний вид
func update_wagon_stats():
	var current_income = money_per_level[wagon_level]
	print("Вагон улучшен до уровня: ", wagon_level, ". Доход: ", current_income)
	
	if not is_inside_tree() or sprite == null:
		return
	# Меняем цвет или спрайт в зависимости от уровня
	match wagon_level:
		1:
			sprite.modulate = Color(1, 1, 1) # Обычный (белый)
		2:
			sprite.modulate = Color(0.7, 0.7, 1) # Голубоватый (стальной)
		3:
			sprite.modulate = Color(1, 0.9, 0.4) # Золотистый (богатый)

signal mouse_hovered(wagon_instance)
signal mouse_unhovered(wagon_instance)
signal clicked(wagon_instance)

func _on_area_2d_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", self)
		print("нажатие") # Отправляем сигнал, что нажали именно на ЭТОТ вагон	


func _on_area_2d_mouse_entered() -> void:
	mouse_hovered.emit(self)


func _on_area_2d_mouse_exited() -> void:
	mouse_unhovered.emit(self)
