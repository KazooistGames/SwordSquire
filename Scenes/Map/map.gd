@tool

extends Node2D

@export var size := Vector2(1280, 640):
	get:
		return size
	set(value):
		size = value
		resize_floor()

@onready var floor_sprite : Sprite2D = $floorSprite
@onready var floor_collider : CollisionShape2D = $floorCollider


func _ready():
	floor_sprite.region_enabled = true
	resize_floor()


func resize_floor():
	var sprite_size : Vector2 = floor_sprite.texture.get_size()
	var floor_height = size.y/2.0
	floor_sprite.region_rect = Rect2(0, 0, size.x, sprite_size.y)
	floor_sprite.position.y = floor_height
	floor_collider.shape.size.x = size.x
	floor_collider.shape.size.y = sprite_size.y - 6
	floor_collider.position.y = floor_height
	
