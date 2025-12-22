
extends Node2D

const base_section_index = 0
const fruit_section_index = 1
const end_section_index = 2

@export var Direction := 1


@onready var branch_segment_prefab := preload("res://Scenes/Foliage/Branch_Segment/Branch_Segment.tscn")

var branch_segments : Array[StaticBody2D] = []


func _ready():
	_grow_branch(randi_range(1, 2))
		
		
func _grow_branch(new_length) -> bool:
	
	for segment in branch_segments:
		segment.queue_free()
		
	branch_segments.clear()
	for index in range(new_length):	
		var base : bool = index == 0	
		var end : bool = index == (new_length - 1)
		_generate_segment(base, end)
	
	return true
	
	
func _generate_segment(base : bool, end : bool) -> bool:
	
	var section_index : int
	
	if end:
		section_index = randi_range(1, 2)	
	else:
		section_index = randi_range(0, 1)
	
	var new_segment : StaticBody2D = branch_segment_prefab.instantiate()	
	new_segment.Direction = Direction
	add_child(new_segment)
	new_segment.set_section(section_index, base)
	
	var horizontal_offset = 24 * branch_segments.size() * sign(Direction)
	new_segment.position = Vector2(horizontal_offset, 0)
	branch_segments.append(new_segment)	
	return true
