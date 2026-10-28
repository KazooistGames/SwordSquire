extends Node

const TITLE = "res://Scenes/TitleScreen.tscn"

# collision layers:
enum LAYER{
	TERRAIN = 1,
	GUY = 1 << 1,
	OBSTACLES = 1 << 4
}


enum GameState{
	menus = 0,
	session = 1,
	loading = 2,
}
var game_state : GameState = GameState.menus
var active_scene : Node


func load_scene(scene_path : String) -> void:
	
	assert(scene_path != '')
	if active_scene == null:
		pass
	elif active_scene.scene_file_path == scene_path:
		push_warning('scene already loaded, reloading: ', scene_path)
		
	var scene_prefab = load(scene_path)
	assert(scene_prefab != null)
	
	PlayerInterface.fade_out()
	await PlayerInterface.faded_out	
	
	game_state = GameState.loading
	Lobby.despawn_players()

	var new_map = scene_prefab.instantiate()
	if active_scene != null:
		active_scene.queue_free()
		
	active_scene = new_map
	add_child(active_scene)
	
	if active_scene.scene_file_path == TITLE:
		game_state = GameState.menus
		PlayerInterface.menu.toggle(true)
	else:
		game_state = GameState.session
		PlayerInterface.menu.toggle(false)
		
	PlayerInterface.fade_in()


func quit() -> void:
	if game_state == GameState.loading:
		return
	elif active_scene.scene_file_path == TITLE:
		get_tree().quit()
	else:
		load_scene(TITLE)
		
		


static func unit_parabola(x:float, period:float):
		var scaled_x = (x-period) / period
		var y = -(pow(scaled_x, 2)) + 1
		return clampf(y, 0.0, 1.0)
