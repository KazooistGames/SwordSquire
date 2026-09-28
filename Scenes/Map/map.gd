class_name Map extends Node2D

var chunks : Dictionary[Vector2i, Chunk] = {}
var base_chunk : Chunk

@onready var chunk_prefab = preload("res://Scenes/Chunk/chunk.tscn")
@onready var container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport

func _ready():
	base_chunk = spawn_chunk(Vector2i.ZERO)
	base_chunk.built.connect(build_wing_chunks)
	
func build_wing_chunks():
	var top : Array[Cell] = base_chunk.get_cell_row(0)
	var bottom : Array[Cell] = base_chunk.get_cell_row(Chunk.GRID_SIZE.y-1)
	var left : Array[Cell] = base_chunk.get_cell_column(0)
	var right : Array[Cell] = base_chunk.get_cell_column(Chunk.GRID_SIZE.x-1)
	return
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Enter"):
		for chunk : Chunk in chunks.values():
			chunk.build()
		
	
func spawn_chunk(coordinates : Vector2i) -> Chunk:
	var new_chunk : Chunk = chunk_prefab.instantiate()
	subviewport.add_child(new_chunk)
	new_chunk.position = coordinates * Chunk.GRID_SIZE * Cell.SIZE
	chunks[coordinates] = new_chunk
	container.size = bounding_container(chunks.keys())
	return new_chunk
	
	
func bounding_container(chunk_coordinates : Array[Vector2i]) -> Vector2:
	var min_x := 0; var max_x := 0; var min_y := 0; var max_y := 0
	for coord : Vector2i in chunk_coordinates:
		if coord.x < min_x:
			min_x = coord.x
		elif coord.x > max_x:
			max_x = coord.x
		if coord.y < min_y:
			min_y = coord.y
		elif coord.y > max_y	:
			max_y = coord.y
			
			
	var range := Vector2i(max_x-min_x + 1, max_y-min_y + 1)
	return range * Chunk.GRID_SIZE * Cell.SIZE
