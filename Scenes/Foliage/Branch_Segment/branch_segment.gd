@tool

extends StaticBody2D

const sprite_dimensions = Vector2(24, 24)

enum Section {
	base = 0,
	fruit = 1,
	end = 2,
}

@export var Section_Index = 0 :
	get:
		return Section_Index
	set(value):
		if set_section(value):
			Section_Index = value
			
@export var Direction := 1
@onready var sprite : Sprite2D = $Sprite2D
@onready var collider : CollisionShape2D = $CollisionShape2D

var vegetation : Node2D = null


func set_section(index, first_segment := false):
	
	if vegetation:
		vegetation.queue_free()
	
	if index * sprite_dimensions.x >= $Sprite2D.texture.get_size().x:
		return false
		
	var x = sprite_dimensions.y * index
	var y = 0
	var w = sprite_dimensions.x
	var h = sprite_dimensions.y
	$Sprite2D.region_rect = Rect2(x, y, w, h)
	$Sprite2D.flip_h = Direction == -1
	
	if index == Section.end:
		$CollisionShape2D.shape.size.x = 8
		$CollisionShape2D.position.x -= 8 * sign(Direction)	
	else:
		$CollisionShape2D.shape.size.x = 24
		$CollisionShape2D.position.x = 0
	
	if index == Section.fruit:
		_attach_fruit()
	elif index == Section.end:
		_attach_canopy()
		
	if first_segment:
		$CollisionShape2D.shape.size.x += 10
		$CollisionShape2D.position.x -= 4 * sign(Direction)
		
	return true
	

func _attach_fruit():	
	var fruit_prefab : PackedScene = load("res://Scenes/Items/Fruit/Fruit.tscn")
	vegetation = fruit_prefab.instantiate()
	add_child(vegetation)
	var y_offset = 8
	vegetation.position = Vector2(-1, y_offset)
	
	
func _attach_canopy():	
	var canopy_prefab : PackedScene = load("res://Scenes/Foliage/Bush/Bush.tscn")
	vegetation = canopy_prefab.instantiate()
	add_child(vegetation)
	var y_offset = -12
	var x_offset = 0.0#-10 * sign(Direction)
	vegetation.position = Vector2(x_offset, y_offset)
