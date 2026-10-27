class_name duel extends Node


@onready var map : Map = $Map


func _ready() -> void:
	map.build()
	map.built.connect(Lobby.spawn_player)
	map.reset.connect(Lobby.despawn_players)
	
