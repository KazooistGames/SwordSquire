extends Node2D

@export var cell_size := 32
@export var grid_size := Vector2i(32,16)

@onready var container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport

var propagation_queue : Array[Vector2i] = []

var grid_sockets : Dictionary[Vector2i, SocketRule]
var grid_candidates : Dictionary[Vector2i, Array]

var cell_templates : Dictionary[SocketRule.SocketType, SocketRule]
var random = RandomNumberGenerator.new()


func _ready():
	cell_templates = load_cell_templates('rules')
	initialize_map()
	seed_map()
	#calculate_grid_entropy()


func _process(_delta):
	if not propagation_queue.is_empty():
		propagate_entropy(propagation_queue.pop_front())
	elif not grid_candidates.is_empty():
		# Find the uncollapsed cell with the fewest candidates
		var best_entropy = SocketRule.SocketType.size()
		var best_coords : Array[Vector2i] = []
		for coord in grid_candidates:
			var count = grid_candidates[coord].size()
			if count < best_entropy:
				best_entropy = count
				best_coords = [coord]
			elif count == best_entropy:
				best_coords.append(coord)

		if not best_coords.is_empty():
			var pick = best_coords.pick_random()
			var type = grid_candidates[pick].pick_random()
			collapse_cell(pick, cell_templates[type])


func initialize_map():
	container.size = grid_size * cell_size
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			grid_sockets[Vector2i(x, y)] = null
			grid_candidates[Vector2i(x, y)] = [1,2,3,4]
	
	
func seed_map():
	var x = random.randi_range(0, grid_size.x-1)
	var y = random.randi_range(0, grid_size.y-1)
	collapse_cell(Vector2i(x,y), cell_templates[SocketRule.SocketType.air])
	x = random.randi_range(0, grid_size.x-1)
	y = random.randi_range(0, grid_size.y-1)
	collapse_cell(Vector2i(x,y), cell_templates[SocketRule.SocketType.grass])
	x = random.randi_range(0, grid_size.x-1)
	y = random.randi_range(0, grid_size.y-1)
	collapse_cell(Vector2i(x,y), cell_templates[SocketRule.SocketType.dirt])
			

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
			


func collapse_cell(coordinates : Vector2i, rule : SocketRule):
	print('Collapsing ', coordinates, ' into ', str(rule.Type))
	if coordinates not in grid_candidates:
		push_error("coords cannot be collapsed")
		return
		
	grid_candidates.erase(coordinates)	
	for neighbor_offset in valid_neighbors(coordinates):
		propagation_queue.push_back(coordinates + neighbor_offset)
	
	grid_sockets[coordinates] = rule
	#cruft for prototyping
	var type_color : Color
	match rule.Type:
		SocketRule.SocketType.air:
			type_color = Color.DARK_CYAN
		SocketRule.SocketType.dirt:
			type_color = Color.SADDLE_BROWN
		SocketRule.SocketType.grass:
			type_color = Color.DARK_GREEN		
		SocketRule.SocketType.cave:
			type_color = Color.DIM_GRAY
		_:
			type_color = Color.PURPLE
			
	var tile : ColorRect = load("res://Scenes/wave_function_collapse/Tile.tscn").instantiate()
	tile.color = type_color
	tile.size = Vector2(cell_size, cell_size)
	subviewport.add_child(tile)
	tile.position = Vector2(coordinates.x, coordinates.y) * cell_size
			
	
func propagate_entropy(coordinates : Vector2i):
	# if this is already collapsed or calculated, skip
	if coordinates not in grid_candidates:
		print(coordinates, ' already collapsed')
		return
		
	var valid_candidates = grid_candidates[coordinates].duplicate()
	
	var neighbors = valid_neighbors(coordinates)
	for relative_position in neighbors:
		var neighbor_rule = grid_sockets[relative_position + coordinates]
		if neighbor_rule == null:
			continue
		for candidate_type : SocketRule.SocketType in grid_candidates[coordinates]:
			var candidate_rule : SocketRule = cell_templates[candidate_type]
			var acceptable = false
			match relative_position:
				Vector2i.UP:
					for socket in candidate_rule.UpSockets:
						if socket in neighbor_rule.DownSockets:
							acceptable = true
				Vector2i.DOWN:
					for socket in candidate_rule.DownSockets:
						if socket in neighbor_rule.UpSockets:
							acceptable = true
				Vector2i.LEFT:
					for socket in candidate_rule.LeftSockets:
						if socket in neighbor_rule.RightSockets:
							acceptable = true
				Vector2i.RIGHT:
					for socket in candidate_rule.RightSockets:
						if socket in neighbor_rule.LeftSockets:
							acceptable = true
			if not acceptable:
				valid_candidates.erase(candidate_type)	
	
	print(coordinates, ' can be ', valid_candidates)
	#no change to candidates, no propagation needed
	if grid_candidates[coordinates].size() == valid_candidates.size():
		return
		
	grid_candidates[coordinates] = valid_candidates
		
	#propagate changes to neighbors
	for relative_position in neighbors:
		var neighbor_coords = coordinates + relative_position
		if neighbor_coords not in grid_candidates:
			continue
		if neighbor_coords not in propagation_queue:
			propagation_queue.append(neighbor_coords)
			print('propagating ', neighbor_coords)
			
	#determine socket rules, collapse if we can
	if grid_candidates[coordinates].size() == 1:
		collapse_cell(coordinates, cell_templates[grid_candidates[coordinates][0]])
		return
	elif grid_candidates[coordinates].size() == 0:
		push_error("Contradiction at ", coordinates)
		return
		
	# After filtering candidates, build virtual sockets for this cell
	var virtual_rules = SocketRule.new()
	virtual_rules.Type = SocketRule.SocketType.wildcard
	for type in grid_candidates[coordinates]:
		var template = cell_templates[type]
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
	grid_sockets[coordinates] = virtual_rules
		
	
func load_cell_templates(subfolder_name: String) -> Dictionary[SocketRule.SocketType, SocketRule]:
	var results: Dictionary[SocketRule.SocketType, SocketRule] = {}
	var script_dir = get_script().resource_path.get_base_dir()
	var target_path = script_dir.path_join(subfolder_name)
	var dir = DirAccess.open(target_path)
	if not dir:
		push_error("Could not open path: " + target_path)
		return {}
		
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
			results[res.Type] = res
			
		file_name = dir.get_next()
		
	return results

	
