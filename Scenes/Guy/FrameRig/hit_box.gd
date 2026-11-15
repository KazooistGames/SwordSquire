class_name HitBox
extends Area2D

@export var Position_Offset : Vector2 = Vector2(8, 0)

@onready var parent : Guy = get_parent().get_parent()

var guys_marked_for_hit : Array[CharacterBody2D] = []
var guys_marked_for_parry : Array[CharacterBody2D] = []
var items_marked_for_smack : Array[PhysicsBody2D] = []

var colliders : Array[CollisionShape2D]

signal parried(Guy)
signal landed_hit(Guy)


func _process(delta : float) -> void:
	position = Position_Offset
	position.x *= parent.facing_direction
	match parent.stance:
		parent.Stance.attacking:
			_process_attacking(delta)
			
		parent.Stance.recovering:
			_process_recovering(delta)		
								
		_:
			pass
			
			
func _process_attacking(_delta : float) -> void:
	var colliding_areas : Array[Area2D] = get_overlapping_areas()	
	for area in colliding_areas:
		var object = area.get_parent()		
		if not parent.is_facing(object):
			pass
		elif object is CharacterBody2D:
			_handle_guy_overlap(object, area)
			
	var colliding_bodies : Array[Node2D] = get_overlapping_bodies()	
	for body in colliding_bodies:		
		if not parent.is_facing(body):
			pass						
		elif body.collision_layer & 512 >= 1:
			_handle_item_overlap(body)

					
func _process_recovering(_delta : float) -> void:
	for guy in guys_marked_for_hit:		
		if guy == null:
			continue
						
		landed_hit.emit(guy)
		
	guys_marked_for_hit.clear()	
	for guy in guys_marked_for_parry:	
		if guy == null:
			continue
			
		parried.emit(guy)
		
	guys_marked_for_parry.clear()
	for item in items_marked_for_smack:
		if item == null:
			continue
			
		#var disposition = (item.global_position - global_position).normalized()
		var direction = Vector2(parent.facing_direction, -1).normalized()
		var magnitude = 250
		item.smack(direction * magnitude)

	items_marked_for_smack.clear()
	

func _handle_guy_overlap(other_guy : CharacterBody2D, object_area : Area2D) -> void:
	if other_guy.state == other_guy.State.dead:
		pass		
	elif guys_marked_for_parry.has(other_guy):
		pass
	elif other_guy.state == other_guy.State.attacking and object_area.collision_layer == 8:
		guys_marked_for_parry.append(other_guy)	
		if guys_marked_for_hit.has(other_guy):
			guys_marked_for_hit.erase(other_guy)
		
	elif guys_marked_for_hit.has(other_guy):
		pass	
	elif object_area.collision_layer == 4:
		guys_marked_for_hit.append(other_guy)
	
	
func _handle_item_overlap(item : PhysicsBody2D) -> void:
	if items_marked_for_smack.has(item):
		pass
	else:
		items_marked_for_smack.append(item)
		
	
