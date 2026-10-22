class_name duel extends Node


@onready var map = $Map


func _ready() -> void:
	map.build()
	map.built.connect(spawn_players)
	

func spawn_players():
	var local_guy = PlayerInterface.guy_prefab.instantiate()
	add_child(local_guy)
	local_guy.position = Vector2i(500, -500)
	PlayerInterface.assume_control(local_guy)
