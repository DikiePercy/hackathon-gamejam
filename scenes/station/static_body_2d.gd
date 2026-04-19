extends StaticBody2D
var pos = position.x

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"../Train".go_trein.connect(_on_train_started)
	$"../Train".stop_trein.connect(_stop_train_started)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_train_started():
	position.x -= 3.5
	

func _stop_train_started():
	position.x -= 3.5
