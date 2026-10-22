extends Node

const TITLE = "res://Title.tscn"

# collision layers:
enum LAYER{
	# PHYSICAL OBJECTS
	TERRAIN = 1 << 0, 		# ground, boundaries, etc.
	STRUCTURE = 1 << 1, 		# buildings, trees, any large or static immovable thing\
	
	OBJECT = 1 << 2, 		# non-equipable but physically reactive rigidbodies
	ITEM = 1 << 3, 			# equipable/consumable physical objects
	
	PERSON = 1 << 4,			# human
	CREATURE = 1 << 5,		# anomalies, monsters, and freaks
	
	# ABSTRACT OBJECTS = 10+
	INTERACTABLE = 1 << 10,  # trigger radius for things like in-game buttons and doors
	AREA = 1 << 11,			# area script triggers and radius of effect type stuff
	
}

const MASK_PHYSICS = (
	LAYER.TERRAIN + LAYER.STRUCTURE
	+ LAYER.OBJECT + LAYER.ITEM
	+ LAYER.PERSON + LAYER.CREATURE
	)
	
const MASK_CHARACTER = (
	LAYER.TERRAIN + LAYER.STRUCTURE
	+ LAYER.PERSON + LAYER.CREATURE
	+ LAYER.OBJECT
)


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
	game_state = GameState.loading
	await PlayerInterface.faded_out	
	
	#should we free the old scene first instead of spawning new scene first?
	var new_map = scene_prefab.instantiate()
	if active_scene != null:
		active_scene.queue_free()
		
	active_scene = new_map
	add_child(active_scene)
	
	if active_scene.scene_file_path == TITLE:
		game_state = GameState.menus
	else:
		game_state = GameState.session
		
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
