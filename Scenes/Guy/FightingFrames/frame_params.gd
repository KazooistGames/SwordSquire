@tool

class_name FrameParams
extends Node

@export var sprite_sheet : CompressedTexture2D = null
@export var texture_size : Vector2i = Vector2i(24,24)
@export var frames_per_second := 3
@export var first_frame_index := 0
@export var last_frame_index := 0
@export var looping := true

@export var hitbox_disabled : bool = false
@export var hitbox_radius : float = 6.0
@export var hitbox_height : float = 24.0
@export var hitbox_rotation : float = 0.0
@export var hitbox_positions : Array[Vector2] = []

@export var hurtbox_radius : float = 6.0
@export var hurtbox_height : float = 24.0
@export var hurtbox_rotation : float = 0.0
@export var hurtbox_positions : Array[Vector2] = []


@export var copy_parent : bool :
	get:
		return copy_parent
	set(value):
		copy_parent = value
		if not value:
			return
		var all_siblings = get_parent().get_children()
		for sibling in all_siblings:
			if sibling == self:
				continue
			if sibling is FrameParams:
				sibling.copy_parent = false
			
			
func _ready():
	copy_parent = false


func _process(_delta: float) -> void:
	if not copy_parent:
		pass
	elif get_parent() == null:
		pass
	elif get_parent() is FightingFrames:
		var params = get_parent()
		sprite_sheet = params.sprite_sheet
		texture_size = params.texture_size
		frames_per_second  = params.frames_per_second
		first_frame_index  = params.first_frame_index
		last_frame_index  = params.last_frame_index
		looping  = params.looping
		hitbox_disabled = params.hitbox_disabled
		hitbox_radius = params.hitbox_radius
		hitbox_height = params.hitbox_height
		hitbox_rotation = params.hitbox_rotation
		hitbox_positions = params.hitbox_positions
		hurtbox_radius = params.hurtbox_radius
		hurtbox_height = params.hurtbox_height
		hurtbox_rotation = params.hurtbox_rotation
		hurtbox_positions = params.hurtbox_positions
