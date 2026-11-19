
class_name FrameSheet
extends Node

@export var texture : CompressedTexture2D
@export var tex_size : Vector2i = Vector2i(24,24)
@export var fps := 3
@export var first_i := 0
@export var last_i := 0
@export var loop := false
var hit_frames : Array[BoxSheet]
var hurt_frames : Array[BoxSheet]


func _ready() -> void:
	if not get_parent() is FrameRig:
		queue_free()
	for child in get_children():
		if not child is BoxSheet:
			continue
		match child.type:
			BoxSheet.Type.hurt:
				hurt_frames.append(child)
			BoxSheet.Type.hit:
				hit_frames.append(child)
