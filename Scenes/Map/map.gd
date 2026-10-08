class_name Map extends Node2D

var all_chunks : Dictionary[Vector2i, Chunk] = {}
var root_chunk : Chunk

@onready var chunk_prefab = preload("res://Scenes/Chunk/chunk.tscn")
@onready var subviewport_container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport
@onready var chunk_box = $SubViewportContainer/SubViewport/Chunks

	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Enter"):
		build_map()

func build_map():
	for chunk : Chunk in all_chunks.values():
			chunk.queue_free()
			all_chunks.erase(all_chunks.find_key(chunk))

			
	root_chunk = spawn_chunk(Vector2i.ZERO, Chunk.DEFAULT_SIZE )	
	root_chunk.build()
	update_viewport_container_bounds()
	
	await root_chunk.built
	var left = extrude_chunk(Vector2i.ZERO, Vector2i.LEFT)
	var right = extrude_chunk(Vector2i.ZERO, Vector2i.RIGHT)

	left.build()
	await left.built 

	right.build()
	await right.built  

	#for chunk : Chunk in all_chunks.values():
		#var chunk_coords = all_chunks.find_key(chunk)
		#var new_chunk := extrude_chunk(chunk_coords, Vector2i.DOWN, Cell.Underground_Template_Set)
		#new_chunk.build()
		#await new_chunk.built
		
	update_viewport_container_bounds()	
	
	# FINAL COLLAPSE INTO ONE GRID/CHUNK
	var temp_chunk_iterator : Array[Chunk] = all_chunks.values().duplicate()
	for chunk : Chunk in temp_chunk_iterator:
		if chunk != root_chunk:
			absorb_chunk(root_chunk, chunk)
			
	var bottom_row := root_chunk.get_cell_row(root_chunk.corner_max.y)
	if bottom_row.any(func(cell : Cell) : return cell.Tag == Cell.Biomes.underground):
		root_chunk.extend(Vector2i.UP, 1, Cell.Underground_Template_Set.pick_random())

	#TODO: check for actual need to extend wings to improve intentionality of map
	root_chunk.extend(Vector2i.LEFT, 2, Cell.Sky_Templates.pick_random())
	root_chunk.extend(Vector2i.RIGHT, 2, Cell.Sky_Templates.pick_random())
	root_chunk.extend(Vector2i.DOWN, 3, Cell.Sky_Templates.pick_random())
	update_viewport_container_bounds()

	
func spawn_chunk(chunk_coordinates : Vector2i, chunk_size : Vector2i, coordinate_offset := Vector2i.ZERO, cell_templates := Cell.Default_Templates) -> Chunk:
	var new_chunk : Chunk = chunk_prefab.instantiate()
	chunk_box.add_child(new_chunk)
	new_chunk.cell_templates = cell_templates
	new_chunk.initialize(chunk_size, coordinate_offset)	
	new_chunk.position = chunk_coordinates * (chunk_size + coordinate_offset) * Cell.SIZE
	all_chunks[chunk_coordinates] = new_chunk
	return new_chunk
	

func extrude_chunk(origin_chunk_coords : Vector2i, direction : Vector2i, cell_templates := Cell.Default_Templates) -> Chunk:
	assert(all_chunks.has(origin_chunk_coords))
	assert([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].has(direction))
	var base = all_chunks[origin_chunk_coords]
	var border : Array[Cell]
	var start : Vector2i
	var increment : Vector2i
	match direction:
		Vector2i.UP:
			border = base.get_cell_row(base.corner_min.y)
			start = Vector2i(base.corner_min.x, base.corner_max.y)
			increment = Vector2i(1, 0)
		Vector2i.DOWN:
			border = base.get_cell_row(base.corner_max.y)
			start = Vector2i(base.corner_min.x, base.corner_min.y)
			increment = Vector2i(1, 0)
		Vector2i.LEFT:
			border = base.get_cell_column(base.corner_min.x)
			start = Vector2i(base.corner_max.x, base.corner_min.y)
			increment = Vector2i(0, 1)
		Vector2i.RIGHT:
			border = base.get_cell_column(base.corner_max.x)
			start = Vector2i(base.corner_min.x, base.corner_min.y)
			increment = Vector2i(0, 1)
			
	var new_coords := origin_chunk_coords + direction		
	var new_chunk = spawn_chunk(new_coords, base.actual_size, base.corner_min, cell_templates)	
	var cell_coordinates := start			
	for cell in border:
		new_chunk.collapse_cell(cell_coordinates, cell)
		cell_coordinates += increment
	return new_chunk
	
	
	
func absorb_chunk(target : Chunk, victim : Chunk):
	#var target_chunk_coord : Vector2i = all_chunks.find_key(target)
	var vore_chunk_coord : Vector2i = all_chunks.find_key(victim)
	var cell_coordinate_offset := Vector2i(victim.position - target.position) / Cell.SIZE
	for coord in victim.grid_cells:
		target.collapse_cell(coord + cell_coordinate_offset, victim.grid_cells[coord])
	victim.queue_free()
	all_chunks.erase(vore_chunk_coord)
	return
		

	
func update_viewport_container_bounds() -> void:

	subviewport_container.size = root_chunk.actual_size * Cell.SIZE * 2 #remove the 2 later, just for testing
	chunk_box.position = -root_chunk.corner_min * Cell.SIZE
	
	'''THIS NEEDS DELETED BEFORE MAKING REAL GAMEPLAY'''
	get_window().content_scale_size = subviewport_container.size
	
	
