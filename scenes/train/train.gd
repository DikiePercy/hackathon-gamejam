extends Node2D

var speed = 200.0
var passengers = 0


var wagons = [] 

func _ready():
	wagons = $WagonContainer.get_children()
