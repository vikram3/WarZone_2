extends "res://objects/characters/unit/Unit.gd"

onready var camera : Camera2D = get_node("camera")

func _ready():
	if is_network_master():
		camera.current = true
		var resource = get_tree().root.get_node("Resources")
		add_child(resource.hud.instance())
