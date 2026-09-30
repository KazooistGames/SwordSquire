class_name Chunk extends Node2D

const GRID_SIZE := Vector2i(16,16)

static var Default_Templates : Array[Cell] = []:
	get():
		if Default_Templates.is_empty():
			Default_Templates = load_Default_Templates("res://Scenes/Cell/prototypes/")
		return Default_Templates

var entropy_propagation_queue : Array[Vector2i] = []

var grid_cells : Dictionary[Vector2i, Cell]
var grid_candidates : Dictionary[Vector2i, Array]

var random = RandomNumberGenerator.new()
var grid_labels : Dictionary[Vector2i, Label] = {}

var contradictions := 0
var contradiction_coordinates := Vector2i.ZERO

signal collapsed_cell
signal initialized
signal built


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
	
	
func _ready():
	initialize()

	
	
func initialize():
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
			grid_candidates[coordinates] = Default_Templates.duplicate()
			# For debugging: show entropy (number of candidates)
			var new_label := Label.new()
			new_label.text = str(Default_Templates.size())
			new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			new_label.position = coordinates * Cell.SIZE
			# Save label and add to viewport
			grid_labels[coordinates] = new_label
			add_child(new_label)		
	initialized.emit()
	

func build():
	while grid_cells.size() < grid_candidates.size():
		perform_wave_collapse_round()
		await get_tree().process_frame
	built.emit()	
	
	
func perform_wave_collapse_round():
	# Find the uncollapsed cells with the fewest candidates and pick one at random
	var collapse_coordinates = lowest_entropy_coordinates().pick_random()
	
	if grid_candidates[collapse_coordinates].size() == 0:
		push_error(collapse_coordinates, ' cannot be collapsed: options not present')
		if collapse_coordinates == contradiction_coordinates: 
			#if we start getting stuck again, remove this check and always + contradictions, only reset when re-initing
			contradictions += 1
		else:
			contradiction_coordinates = collapse_coordinates
			contradictions = 0
		backtrack_cell_neighbors(collapse_coordinates)
		return

	#pick a random viable template from virtual cells
	var chosen_template = grid_candidates[collapse_coordinates].pick_random()
	collapse_cell(collapse_coordinates, chosen_template)
	# recalculate grid entropy
	while not entropy_propagation_queue.is_empty():
		calculate_entropy(entropy_propagation_queue.pop_front())			
	

func lowest_entropy_coordinates() -> Array[Vector2i]:
	var results : Array[Vector2i] = []
	if not grid_candidates.is_empty():	
		#init search with no-entropy size
		var best_entropy : int = Default_Templates.size()
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


func collapse_cell(coordinates : Vector2i, chosen : Cell):

	grid_cells[coordinates] = chosen
	grid_candidates[coordinates] = [chosen]
	
	var tile : Node = chosen.collapse()
	add_child(tile)
	tile.position = coordinates * Cell.SIZE
	
	for neighbor_offset in valid_neighbor_offsets(coordinates):
		var neighbor_coordinates = coordinates + neighbor_offset
		if not neighbor_coordinates in grid_cells:		
			entropy_propagation_queue.push_back(coordinates + neighbor_offset)
		
	if grid_cells.size() == grid_candidates.size():
		collapsed_cell.emit()
		
	
	
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
		collapse_cell(coordinates, grid_candidates[coordinates][0])
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
			grid_candidates[neighbor_coordinates] = Default_Templates.duplicate()
			entropy_propagation_queue.push_back(coordinates)
			if depth < contradictions:
				backtrack_cell_neighbors(neighbor_coordinates, depth+1)
	grid_candidates[coordinates] = Default_Templates.duplicate()
			
			
func get_cell_row(y_index : int) -> Array[Cell]:
	if y_index > GRID_SIZE.y-1 or y_index < 0:
		return []
	var results : Array[Cell] = []
	var coordinates := Vector2i(0, y_index)
	for x in range(GRID_SIZE.x):
		coordinates.x = x
		results.append(grid_cells[coordinates])
	return results
	
	
func get_cell_column(x_index : int) -> Array[Cell]:
	if x_index > GRID_SIZE.x-1 or x_index < 0:
		return []
	var results : Array[Cell] = []
	var coordinates := Vector2i(x_index, 0)
	for y in range(GRID_SIZE.y):
		coordinates.y = y
		results.append(grid_cells[coordinates])
	return results
