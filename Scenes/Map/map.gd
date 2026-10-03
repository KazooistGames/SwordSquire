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
	root_chunk = spawn_chunk(Vector2i.ZERO)		
	update_viewport_container_bounds()
	root_chunk.build()
	await root_chunk.built
	var left = extrude_chunk(Vector2i.ZERO, Vector2i.LEFT)
	left.build()
	await left.built 
	absorb_chunk(root_chunk, left)
	var right = extrude_chunk(Vector2i.ZERO, Vector2i.RIGHT)
	right.build()
	await right.built  
	absorb_chunk(root_chunk, right)
	
	root_chunk.extend(Vector2i.DOWN, 3, Cell.Sky_Templates.pick_random())
	update_viewport_container_bounds()
	
	
func _absorb_into_root(new_chunk : Chunk):
	absorb_chunk(root_chunk, new_chunk)
	
	
func spawn_chunk(coordinates : Vector2i) -> Chunk:
	var new_chunk : Chunk = chunk_prefab.instantiate()
	chunk_box.add_child(new_chunk)
	new_chunk.position = coordinates * Chunk.GRID_SIZE * Cell.SIZE
	all_chunks[coordinates] = new_chunk
	return new_chunk
	

func extrude_chunk(origin : Vector2i, direction : Vector2i) -> Chunk:
	assert(all_chunks.has(origin))
	assert([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].has(direction))
	var base = all_chunks[origin]
	var border : Array[Cell]
	var start : Vector2i
	var increment : Vector2i
	match direction:
		Vector2i.UP:
			border = base.get_cell_row(0)
			start = Vector2i(0, Chunk.GRID_SIZE.y-1)
			increment = Vector2i(1, 0)
		Vector2i.DOWN:
			border = base.get_cell_row(Chunk.GRID_SIZE.y-1)
			start = Vector2i(0, 0)
			increment = Vector2i(1, 0)
		Vector2i.LEFT:
			border = base.get_cell_column(0)
			start = Vector2i(Chunk.GRID_SIZE.x-1, 0)
			increment = Vector2i(0, 1)
		Vector2i.RIGHT:
			border = base.get_cell_column(Chunk.GRID_SIZE.x-1)
			start = Vector2i(0, 0)
			increment = Vector2i(0, 1)
			
	var new_chunk = spawn_chunk(origin + direction)	
	var coordinates := start			
	for cell in border:
		new_chunk.collapse_cell(coordinates, cell)
		coordinates += increment
	return new_chunk
	
	
func absorb_chunk(target : Chunk, victim : Chunk):
	var target_coord : Vector2i = all_chunks.find_key(target)
	var vore_coord : Vector2i = all_chunks.find_key(victim)
	var offset := (vore_coord - target_coord) * Chunk.GRID_SIZE
	for coord in victim.grid_cells:
		target.collapse_cell(coord + offset, victim.grid_cells[coord])
	victim.queue_free()
	all_chunks.erase(vore_coord)
	return
	
	
func update_viewport_container_bounds() -> void:
	var min_x := 0; var max_x := 0; var min_y := 0; var max_y := 0
	for coord : Vector2i in all_chunks.keys():
		if coord.x < min_x:
			min_x = coord.x
		elif coord.x > max_x:
			max_x = coord.x
		if coord.y < min_y:
			min_y = coord.y
		elif coord.y > max_y:
			max_y = coord.y
			
	var range := Vector2i(max_x-min_x, max_y-min_y)
	subviewport_container.size = (range + Vector2i.ONE) * root_chunk.actual_size * Cell.SIZE
	chunk_box.position = range * root_chunk.actual_size * Cell.SIZE / 2
	
	'''THIS NEEDS DELETED BEFORE MAKING REAL GAMEPLAY'''
	get_window().content_scale_size = subviewport_container.size
	
	
