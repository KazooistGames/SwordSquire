extends Node

'''
manages player connectivity and provides gameplay harness lifecycle API
'''

var player_guys : Array[Guy] = []


	
func spawn_player() -> Guy:
	var new_guy : Guy = load("res://Scenes/Guy/Archetypes/Swordsman/Swordsman.tscn").instantiate()
	player_guys.append(new_guy)
	add_child(new_guy)
	var harness : GameplayHarness = GameplayHarness.new()
	new_guy.add_child(harness)
	PlayerInterface.camera.guy = new_guy
	new_guy.position.x = 500
	return new_guy
	
	
func despawn_players():
	for guy in player_guys:
		guy.queue_free()
	player_guys.clear()
	PlayerInterface.camera.guy = null
