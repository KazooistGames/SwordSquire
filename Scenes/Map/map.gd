class_name Map extends Node2D


var chunks : Dictionary[Vector2i, Chunk] = {}

@onready var chunk_prefab = preload("res://Scenes/Chunk/chunk.tscn")
@onready var container = $SubViewportContainer
@onready var subviewport = $SubViewportContainer/SubViewport

func _ready():
	spawn_chunk(Vector2i.ZERO)
	
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
