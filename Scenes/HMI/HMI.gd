extends Camera2D

@export var player : CharacterBody2D = null
@export var target_position := Vector2(0, 0)
@export var reposition_speed := 10

@onready var hp_bar : ColorRect = $CanvasLayer/hp_bar
@onready var strength_bar : ColorRect = $CanvasLayer/strength_bar
@onready var fov_light : PointLight2D = $PointLight2D

func _process(delta : float) -> void:
	
	if player:
		_movement_inputs(delta)
		_combat_inputs(delta)
		_update_hud(delta)
		fov_light.global_position = player.global_position
		_update_bush_transparency()
		_update_guy_hidden()
		
	if Input.is_action_just_pressed("Interact"):
		player.interact()
		

func _movement_inputs(_delta : float) -> void:

	if Input.is_action_pressed("moveLeft") and Input.is_action_pressed("moveRight"):
		player.left_right = 0
	elif Input.is_action_pressed("moveRight"):
		player.left_right = 1
	elif Input.is_action_pressed("moveLeft"):
		player.left_right = -1
	else:
		player.left_right = 0
	if Input.is_action_just_pressed("moveUp"):
		player.jump()
	elif Input.is_action_just_pressed("moveDown"):
		player.duck()
		

func _combat_inputs(_delta : float) -> void:
	if Input.is_action_just_pressed("smash"):
		player.charge()
	elif Input.is_action_just_released("smash"):
		player.release()

		
func _physics_process(delta):
	var offset_from_target : Vector2 = target_position - position
	var curve = pow(offset_from_target.length() / 10.0, 2)
	position = position.move_toward(target_position, reposition_speed * curve * delta)


func _update_hud(_delta):
	hp_bar.size.x = player.HP
	strength_bar.size.x = player.Energy * 100
	
func _update_bush_transparency():
	var bushes : Array[Node] = get_tree().get_nodes_in_group("Bush")
	for bush in bushes:
		bush.Transparent = bush.inhabitants.has(player)

func _update_guy_hidden():
	var guys : Array[Node] = get_tree().get_nodes_in_group("Guy")
	for guy in guys:
		if guy == player:
			pass
		else:
			guy.sprite.visible = can_see_through_all_concealments(guy)
		
func can_see_through_all_concealments(other_guy : CharacterBody2D) -> bool:
	for concealment in other_guy.Concealments:
		if concealment == null:
			continue
		elif not player.Concealments.has(concealment):
			return false
	return true
		
