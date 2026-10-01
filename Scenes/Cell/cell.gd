class_name Cell extends Resource

const SIZE := Vector2i(48, 48)


enum Biomes{
	wildcard = 0,
	sky = 1,
	ground = 2,
	underground = 3
	}
	
@export var Tag : Biomes

enum Cardinals{
	UP = 0,
	RIGHT = 1,
	DOWN = 2,
	LEFT = 3
}

@export var Sockets : Dictionary[Cardinals, Biomes] ={
	Cardinals.UP : Biomes.wildcard,
	Cardinals.RIGHT :Biomes.wildcard,
	Cardinals.DOWN : Biomes.wildcard,
	Cardinals.LEFT : Biomes.wildcard
}

enum Configuration{
	default,
	cw,
	ccw
}
var orientation : Configuration = Configuration.default
var is_flipped = false

func collapse():
	var color := ColorRect.new()
	color.size = SIZE
	var tile : CollisionObject2D
	match Tag:
		Biomes.sky:
			tile = Area2D.new()
			color.color = Color.DARK_CYAN
		Biomes.ground:
			tile = StaticBody2D.new()
			color.color = Color.SADDLE_BROWN
			var collider := CollisionShape2D.new()
			collider.shape = RectangleShape2D.new()
			collider.shape.size = SIZE		
			tile.add_child(collider)
			collider.position = SIZE	/ 2.0
		Biomes.underground:
			tile = Area2D.new()
			color.color = Color.DARK_SLATE_GRAY
			
	tile.add_child(color)		
	return tile
	
func fits(other : Cell, direction : Vector2i):
	var dir = _translate_vector_to_cardinal(direction)

	var my_socket = Sockets[dir]
	var their_socket = other.Sockets[_mirrored(dir)]
	
	var they_fit = false
	if my_socket == other.Tag or my_socket == Biomes.wildcard or other.Tag == Biomes.wildcard:
		they_fit = true
		
	var i_fit = false
	if their_socket == Tag or their_socket == Biomes.wildcard or Tag == Biomes.wildcard:
		i_fit = true
	
	return i_fit and they_fit

		
func rotated_cw():
	var rotated_cell : Cell = self.duplicate(true) 
	for dir in Cardinals.values():
		rotated_cell.Sockets[(dir + 1) % 4] = Sockets[dir]		
	rotated_cell.orientation = Cell.Configuration.cw
	return rotated_cell
	
func rotated_ccw():
	var rotated_cell : Cell = self.duplicate(true) 
	for dir in Cardinals.values():
		rotated_cell.Sockets[(dir + 3) % 4] = Sockets[dir]		
	rotated_cell.orientation = Cell.Configuration.ccw
	return rotated_cell	
	
func flipped():
	var flipped_cell : Cell = self.duplicate(true) 
	flipped_cell.Sockets[Cardinals.LEFT] = Sockets[Cardinals.RIGHT]
	flipped_cell.Sockets[Cardinals.RIGHT] = Sockets[Cardinals.LEFT]
	flipped_cell.is_flipped = true
	return flipped_cell	
	

func is_assymmetrical():
	return Sockets[Cardinals.LEFT] != Sockets[Cardinals.RIGHT]
		
func _mirrored(direction : Cardinals):
	return (direction + 2) % 4
	
			
func _translate_vector_to_cardinal(direction : Vector2i) -> Cardinals:
	match direction:
		Vector2i.UP: return Cardinals.UP
		Vector2i.DOWN: return Cardinals.DOWN
		Vector2i.LEFT: return Cardinals.LEFT
		Vector2i.RIGHT: return Cardinals.RIGHT
		_: return Cardinals.UP
		
		

static var Default_Templates : Array[Cell] = []:
	get():
		if Default_Templates.is_empty():
			Default_Templates = load_Default_Templates("res://Scenes/Cell/prototypes/")
		return Default_Templates


static var Underground_Template_Set : Array[Cell]:
	get():
		var results = []
		results.append_array((load_cell_template('res://Scenes/Cell/prototypes/ground.tres')))
		results.append_array((load_cell_template('res://Scenes/Cell/prototypes/cave.tres')))
		results.append_array((load_cell_template('res://Scenes/Cell/prototypes/hole.tres')))
		results.append_array((load_cell_template('res://Scenes/Cell/prototypes/tunnel.tres')))
		return results
						

static func load_Default_Templates(target_path) -> Array[Cell]:
	var results: Array[Cell] = []
	var dir = DirAccess.open(target_path)
	if not dir:
		push_error("Could not open path: " + target_path)
		return []
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		if file_name.ends_with(".import"):
			file_name = dir.get_next()
			continue
			
		var full_path = target_path.path_join(file_name)
		var variants = load_cell_template(full_path)
		results.append_array(variants)
		file_name = dir.get_next()
		
	return results


#loads a cell template and procedurally generates all of its variants
static func load_cell_template(full_path) -> Array[Cell]:

	# Fix for .remap files in exported builds
	if full_path.ends_with(".remap"):
		full_path = full_path.get_basename()
		
	#get orientation varieties
	var results: Array[Cell] = []
	var template : Cell = load(full_path)
	var orientations = [template, template.rotated_cw(), template.rotated_ccw()]
	results.append_array(orientations)
	#flipped versions of all orientations
	for cell : Cell in orientations:
		if cell.is_assymmetrical():
			results.append(cell.flipped())
			
	return results
