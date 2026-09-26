class_name Chunk extends Node2D

const GRID_SIZE := Vector2i(32,16)

static var Cell_Templates : Array[Cell] = []:
	get():
		if Cell_Templates.is_empty():
			Cell_Templates = load_Cell_Templates()
		return Cell_Templates

var entropy_propagation_queue : Array[Vector2i] = []

var grid_cells : Dictionary[Vector2i, Cell]
var grid_candidates : Dictionary[Vector2i, Array]

var random = RandomNumberGenerator.new()
var grid_labels : Dictionary[Vector2i, Label] = {}

var contradictions := 0
var contradiction_coordinates := Vector2i.ZERO

signal generated
signal initialized

func _process(_delta):
	if grid_cells.size() < grid_candidates.size():
		perform_wave_collapse_round()

	
static func load_Cell_Templates() -> Array[Cell]:
	var results: Array[Cell] = []
	var target_path = "res://Scenes/Cell/prototypes/"
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
			
		var template : Cell = load(full_path)
		var template_cw = template.rotated_cw()
		var template_ccw = template.rotated_ccw()
		var permuations = [template, template_cw, template_ccw]
		
		results.append_array(permuations)
		
		for cell : Cell in permuations:
			if cell.is_assymmetrical():
				results.append(cell.flipped())

		if template.is_assymmetrical():
			results.append(template.flipped())
		file_name = dir.get_next()
		
	return results
	

func build():
	# Set container size
	
	# Clear previous data
	grid_cells.clear()
	for child in get_children():
		child.queue_free()
	grid_labels.clear()
	grid_candidates.clear()
	for x in range(GRID_SIZE.x):
		for y in range(GRID_SIZE.y):
			var coordinates = Vector2i(x, y)
			# Duplicate the full template list for this cell
			grid_candidates[coordinates] = Cell_Templates.duplicate()
			# For debugging: show entropy (number of candidates)
			var new_label := Label.new()
			new_label.text = str(Cell_Templates.size())
			new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			new_label.position = coordinates * Cell.SIZE
			# Save label and add to viewport
			grid_labels[coordinates] = new_label
			add_child(new_label)		
			
	initialized.emit()			
	
	
func perform_wave_collapse_round():
	# Find the uncollapsed cells with the fewest candidates
	var collapse_options = lowest_entropy_coordinates()
	# collapse one of them
	collapse_cell(collapse_options.pick_random())
	# recalculate grid entropy
	while not entropy_propagation_queue.is_empty():
		calculate_entropy(entropy_propagation_queue.pop_front())			


func lowest_entropy_coordinates() -> Array[Vector2i]:
	var results : Array[Vector2i] = []
	if not grid_candidates.is_empty():	
		#init search with no-entropy size
		var best_entropy : int = Cell_Templates.size()
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
		if coordinates == contradiction_coordinates:
			contradictions += 1
		else:
			contradiction_coordinates = coordinates
			contradictions = 0
		backtrack_cell_neighbors(coordinates)
		return

	#pick a random viable template from virtual cells
	var cell_options = grid_candidates[coordinates]
	var chosen : Cell = cell_options.pick_random()
	grid_cells[coordinates] = chosen
	grid_candidates[coordinates] = [chosen]
	
	#convert it into a tile
	#print(
		#'Collapsing ', coordinates, 
		#' into ', chosen.resource_name, ' ', 
		#Cell.Configuration.find_key(chosen.orientation)
		#)	
	var tile : Node = chosen.collapse()
	add_child(tile)
	tile.position = coordinates * Cell.SIZE
	
	for neighbor_offset in valid_neighbor_offsets(coordinates):
		var neighbor_coordinates = coordinates + neighbor_offset
		if not neighbor_coordinates in grid_cells:		
			entropy_propagation_queue.push_back(coordinates + neighbor_offset)
		
	if grid_cells.size() == grid_candidates.size():
		generated.emit()
		
	
	
func valid_neighbor_offsets(coordinates : Vector2i) -> Array[Vector2i]:
	var results : Array[Vector2i] = []
	if coordinates.x > 0:
		results.append(Vector2i.LEFT)
	if coordinates.x < GRID_SIZE.x-1:
		results.append(Vector2i.RIGHT)
	if coordinates.y > 0:
		results.append(Vector2i.UP)
	if coordinates.y < GRID_SIZE.y-1:
		results.append(Vector2i.DOWN)
	return results	
		
	
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

	#no change to candidates, no propagation needed
	if needs_removed.size() == 0:
		return	
		
	# make entropy updates
	for candidate in needs_removed:
		grid_candidates[coordinates].erase(candidate)
	grid_labels[coordinates].text = str(grid_candidates[coordinates].size())
	
	#determine socket rules, collapse if we can
	if grid_candidates[coordinates].size() == 1:
		collapse_cell(coordinates)
	elif grid_candidates[coordinates].size() == 0:
		push_error("Contradiction at %s, depth %s" % [coordinates, contradictions])
		return
	
	#propagate changes to neighbors
	for relative_position in neighbor_offsets:
		var neighbor_coords = coordinates + relative_position
		if neighbor_coords not in entropy_propagation_queue: #de-duplicate
			entropy_propagation_queue.append(neighbor_coords)
			#print('propagating ', neighbor_coords)
			
func backtrack_cell_neighbors(coordinates, depth=0):
	var neighbor_offsets = valid_neighbor_offsets(coordinates)
	for offset in neighbor_offsets:
		var neighbor_coordinates = coordinates + offset
		if neighbor_coordinates in grid_cells:
			grid_cells.erase(neighbor_coordinates)
			grid_candidates[neighbor_coordinates] = Cell_Templates.duplicate()
			entropy_propagation_queue.push_back(coordinates)
			if depth < contradictions:
				backtrack_cell_neighbors(neighbor_coordinates, depth+1)
	grid_candidates[coordinates] = Cell_Templates.duplicate()
			

	

			
