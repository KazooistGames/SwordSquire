
class_name FrameSheet
extends Node

@export var sheet : CompressedTexture2D = null
@export var tex_size : Vector2i = Vector2i(24,24)
@export var fps := 3
@export var first_i := 0
@export var last_i := 0
@export var loop := false

			
func _ready():
	if not get_parent() is FrameRig:
		queue_free()
