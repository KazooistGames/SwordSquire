extends Node2D

@export var cell_size := 32
@export var grid_size := Vector2i(4,4)

@onready var container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport

var propagation_queue : Array[Vector2i] = []

var grid_cells : Dictionary[Vector2i, Cell]
var grid_candidates : Dictionary[Vector2i, Array]

var cell_templates : Array[Cell]
var random = RandomNumberGenerator.new()

var grid_labels : Dictionary[Vector2i, Label] = {}


func _ready():
	cell_templates = load_cell_templates('cells')
	initialize_map()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Enter"):
		perform_wave_collapse_round()

#func _process(_delta):
	#perform_wave_collapse_round()


func initialize_map():
	container.size = grid_size * cell_size
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var coordinates = Vector2i(x,y)
			grid_candidates[coordinates] = cell_templates.duplicate()
			#for debugging purposes, render the entropy of each cell
			var new_label := Label.new()
			grid_labels[coordinates] = new_label
			subviewport.add_child(new_label)
			new_label.position = coordinates * cell_size
			new_label.text = str(cell_templates.size())
			new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	

func perform_wave_collapse_round():
	if grid_cells.size() == grid_candidates.size():
		return
	# Find the uncollapsed cells with the fewest candidates
	var collapse_options = lowest_entropy_coordinates()
	# collapse one of them
	collapse_cell(collapse_options.pick_random())
	# recalculate grid entropy
	while not propagation_queue.is_empty():
		calculate_entropy(propagation_queue.pop_front())			


func lowest_entropy_coordinates() -> Array[Vector2i]:
	var results : Array[Vector2i] = []
	if not grid_candidates.is_empty():	
		#init search with no-entropy size
		var best_entropy : int = cell_templates.size()
		# iterate all uncollapsed tiles
		for coord in grid_candidates:
			if coord in grid_cells:
				continue
			var count = grid_candidates[coord].size()
			if count < best_entropy:
				best_entropy = count
				results = [coord]
			elif count == best_entropy:
				results.append(coord)
	
	return results


func collapse_cell(coordinates : Vector2i):
	
	if grid_candidates[coordinates].size() == 0:
		push_error(coordinates, ' cannot be collapsed: options not present')
		return

	#pick a random viable template from virtual cells
	var cell_options = grid_candidates[coordinates]
	var chosen_template : Cell = cell_options.pick_random()
	grid_cells[coordinates] = chosen_template
	grid_candidates[coordinates] = [chosen_template]
	
	#convert it into a tile
	print('Collapsing ', coordinates, ' into ', chosen_template.Tag as Cell.Socket)	
	var tile : Node = chosen_template.collapse()
	tile.size = Vector2(cell_size, cell_size)
	subviewport.add_child(tile)
	tile.position = Vector2(coordinates.x, coordinates.y) * cell_size
	
	for neighbor_offset in valid_neighbor_offsets(coordinates):
		propagation_queue.push_back(coordinates + neighbor_offset)
		
	
func calculate_entropy(coordinates : Vector2i):
	# if this is already collapsed or calculated, skip
	if coordinates not in grid_candidates:
		print(coordinates, ' already collapsed')
		return
		
	var needs_removed = []
	var neighbor_offsets = valid_neighbor_offsets(coordinates)
	for candidate : Cell in grid_candidates[coordinates]:
		for offset in neighbor_offsets:
			var has_a_match = false
			for neighbor_option in grid_candidates[coordinates + offset]:
				if neighbor_option == null:
					continue
				elif candidate.fits(neighbor_option, offset):
					has_a_match = true
					break
			if has_a_match:
				pass
			elif candidate in needs_removed:
				pass
			else:
				needs_removed.append(candidate)
				break
	
	print(coordinates, ' can be ', grid_candidates[coordinates].size(), ' things')
	
	#no change to candidates, no propagation needed
	if needs_removed.size() == 0:
		return
		
	for candidate in needs_removed:
		grid_candidates[coordinates].erase(candidate)
		
	grid_labels[coordinates].text = str(grid_candidates[coordinates])
	
	#determine socket rules, collapse if we can
	if grid_candidates[coordinates].size() == 1:
		collapse_cell(coordinates)
	elif grid_candidates[coordinates].size() == 0:
		push_error("Contradiction at ", coordinates)
		return
	
	#propagate changes to neighbors
	for relative_position in neighbor_offsets:
		var neighbor_coords = coordinates + relative_position
		if neighbor_coords not in grid_candidates:
			continue
		if neighbor_coords not in propagation_queue and neighbor_coords in grid_candidates:
			propagation_queue.append(neighbor_coords)
			print('propagating ', neighbor_coords)
			

	
func valid_neighbor_offsets(coordinates : Vector2i) -> Array[Vector2i]:
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

	
