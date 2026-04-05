extends Node2D

@export var cell_size := 32
@export var grid_size := Vector2i(32,16)

@onready var container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport

var propagation_queue : Array[Vector2i] = []

var grid_cells : Dictionary[Vector2i, Cell]
var virtual_cells : Dictionary[Vector2i, Array]

var cell_templates : Array[Cell]
var random = RandomNumberGenerator.new()

var grid_labels : Dictionary[Vector2i, Label] = {}


func _ready():
	cell_templates = load_cell_templates('cells')
	initialize_map()

		
func _process(_delta):
	perform_wave_collapse_round()


func initialize_map():
	container.size = grid_size * cell_size
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var coordinates = Vector2i(x,y)
			grid_cells[coordinates] = null
			virtual_cells[coordinates] = range(cell_templates.size())
			var new_label := Label.new()
			grid_labels[coordinates] = new_label
			subviewport.add_child(new_label)
			new_label.position = coordinates * cell_size
			new_label.text = str(cell_templates.size())
			new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	

func perform_wave_collapse_round():
	# Find the uncollapsed cell with the fewest candidates		
	var entropic_cell = lowest_entropy_cell()
	if entropic_cell:
		collapse_cell(entropic_cell)
	while not propagation_queue.is_empty():
		propagate_entropy(propagation_queue.pop_front())			


func lowest_entropy_cell() -> Cell:
	if not virtual_cells.is_empty():	
		#init search with no-entropy size
		var best_entropy : int = cell_templates.size()
		var best_option_coordinates : Array[Vector2i] = []
		# iterate all uncollapsed tiles
		for coord in virtual_cells:
			var count = virtual_cells[coord].size()
			if count < best_entropy:
				best_entropy = count
				best_option_coordinates = [coord]
			elif count == best_entropy:
				best_option_coordinates.append(coord)
		if not best_option_coordinates.is_empty():
			return grid_cells[best_option_coordinates.pick_random()]
	
	return null


func valid_neighbors(coordinates : Vector2i) -> Array[Vector2i]:
	var results : Array[Vector2i] = []
	if coordinates.x > 0:
		results.append(Vector2i.LEFT)
	if coordinates.x < grid_size.x-1:
		results.append(Vector2i.RIGHT)
	if coordinates.y > 0:
		results.append(Vector2i.UP)
	if coordinates.y < grid_size.y-1:
		results.append(Vector2i.DOWN)
	return results
			

func collapse_cell(coordinates : Vector2i):
	
	if coordinates not in virtual_cells:
		push_error(coordinates, ' cannot be collapsed')
		return
		
	#pick a random viable template from virtual cells
	var cell_choice : Cell = virtual_cells[coordinates].pick_random()
	grid_cells[coordinates] = cell_choice
	
	#collapse it into a tile
	var tile = cell_choice.collapse()
	print('Collapsing ', coordinates, ' into ', str(tile.Name))	

	virtual_cells.erase(coordinates)	
	for neighbor_offset in valid_neighbors(coordinates):
		propagation_queue.push_back(coordinates + neighbor_offset)
	
	subviewport.add_child(tile)
	tile.position = Vector2(coordinates.x, coordinates.y) * cell_size
			
	
func propagate_entropy(coordinates : Vector2i):
	# if this is already collapsed or calculated, skip
	if coordinates not in virtual_cells:
		print(coordinates, ' already collapsed')
		return
		
	var valid_candidates = virtual_cells[coordinates].duplicate()
	
	var neighbors = valid_neighbors(coordinates)
	for relative_position in neighbors:
		var neighbor = grid_cells[relative_position + coordinates]
		if neighbor == null:
			continue
		for template_index : int in virtual_cells[coordinates]:
			var candidate : Cell = cell_templates[template_index]
			var acceptable = false
			match relative_position:
				Vector2i.UP:
					for socket in candidate.UpSockets:
						if socket in neighbor.DownSockets:
							acceptable = true
				Vector2i.DOWN:
					for socket in candidate.DownSockets:
						if socket in neighbor.UpSockets:
							acceptable = true
				Vector2i.LEFT:
					for socket in candidate.LeftSockets:
						if socket in neighbor.RightSockets:
							acceptable = true
				Vector2i.RIGHT:
					for socket in candidate.RightSockets:
						if socket in neighbor.LeftSockets:
							acceptable = true
			if not acceptable:
				valid_candidates.erase(template_index)	
	
	print(coordinates, ' can be ', valid_candidates)
	#no change to candidates, no propagation needed
	if virtual_cells[coordinates].size() == valid_candidates.size():
		return
		
	virtual_cells[coordinates] = valid_candidates
	grid_labels[coordinates].text = str(valid_candidates.size())
	#propagate changes to neighbors
	for relative_position in neighbors:
		var neighbor_coords = coordinates + relative_position
		if neighbor_coords not in virtual_cells:
			continue
		if neighbor_coords not in propagation_queue and neighbor_coords in virtual_cells:
			propagation_queue.append(neighbor_coords)
			print('propagating ', neighbor_coords)
			
	#determine socket rules, collapse if we can
	if virtual_cells[coordinates].size() == 1:
		collapse_cell(coordinates)
		return
	elif virtual_cells[coordinates].size() == 0:
		push_error("Contradiction at ", coordinates)
		return
		
	# After filtering candidates, build virtual sockets for this cell
	var virtual_rules = Cell.new()
	for template_index in virtual_cells[coordinates]:
		var template = cell_templates[template_index]
		for s in template.UpSockets:
			if s not in virtual_rules.UpSockets:
				virtual_rules.UpSockets.append(s)
		for s in template.DownSockets:
			if s not in virtual_rules.DownSockets:
				virtual_rules.DownSockets.append(s)
		for s in template.LeftSockets:
			if s not in virtual_rules.LeftSockets:
				virtual_rules.LeftSockets.append(s)
		for s in template.RightSockets:
			if s not in virtual_rules.RightSockets:
				virtual_rules.RightSockets.append(s)
											
	grid_cells[coordinates] = virtual_rules
		
	
func load_cell_templates(subfolder_name: String) -> Array[Cell]:
	var results: Array[Cell] = []
	var script_dir = get_script().resource_path.get_base_dir()
	var target_path = script_dir.path_join(subfolder_name)
	var dir = DirAccess.open(target_path)
	if not dir:
		push_error("Could not open path: " + target_path)
		return []
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			continue
		if file_name.ends_with(".import"):
			continue
			
		var full_path = target_path.path_join(file_name)
		# Fix for .remap files in exported builds
		if full_path.ends_with(".remap"):
			full_path = full_path.replace(".remap", "")	
			
		var res = load(full_path)
		if res:
			results.append(res)
			
		file_name = dir.get_next()
		
	return results

	
