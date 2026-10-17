extends Camera2D

const base_x_speed := 0.25
const base_y_speed := 0.25
const y_range := 50

@export var guy : Guy = null
@export var target_position := Vector2(0, 0)

@onready var hp_bar : ColorRect = $CanvasLayer/hp_bar
@onready var strength_bar : ColorRect = $CanvasLayer/strength_bar
@onready var fov_light : PointLight2D = $PointLight2D

var x_target := 0.0
var y_target := 0.0
var y_offset := -6.0
var y_deadbanded := false
var y_deadband_timer := 0.0


func _process(delta : float) -> void:
	if guy:
		target_position = guy.global_position
		fov_light.global_position = guy.global_position
		_movement_inputs(delta)
		_combat_inputs(delta)
		_update_hud(delta)
		_update_bush_transparency()
		_update_guy_hidden()	
	if Input.is_action_just_pressed("Interact"):
		guy.interact()
		

func _movement_inputs(_delta : float) -> void:
	if Input.is_action_pressed("moveLeft") and Input.is_action_pressed("moveRight"):
		guy.left_right = 0
	elif Input.is_action_pressed("moveRight"):
		guy.left_right = 1
	elif Input.is_action_pressed("moveLeft"):
		guy.left_right = -1
	else:
		guy.left_right = 0
	if Input.is_action_just_pressed("moveUp"):
		guy.jump()
	elif Input.is_action_just_pressed("moveDown"):
		guy.duck()
		

func _combat_inputs(_delta : float) -> void:
	if Input.is_action_just_pressed("smash"):
		guy.charge()
	elif Input.is_action_just_released("smash"):
		guy.release()

		
func _physics_process(delta):
	if guy:
		_process_x(delta)
		_process_y(delta)
	

func _process_x(delta):
	x_target = guy.global_position.x
	var offset_from_target : float = abs(x_target - global_position.x)
	var speed = base_x_speed + offset_from_target / 20.0
	global_position.x = move_toward(global_position.x, target_position.x, speed)


func _process_y(delta):
	var offset_from_target : float = abs(y_target - global_position.y)
	if y_deadband_timer >= 3.0:
		y_deadbanded = false
		y_deadband_timer = 0.0
	elif y_deadbanded:
		y_target = guy.global_position.y + y_offset
		y_deadband_timer += delta
	else:
		var speed = base_y_speed + offset_from_target/25.0
		global_position.y = move_toward(global_position.y, y_target, speed)
		if abs(y_target - guy.global_position.y) >= y_range:
			y_target = guy.global_position.y + y_offset
			
	if offset_from_target >= y_range:
		y_deadbanded = false
		y_target = guy.global_position.y
	elif offset_from_target <= 0.01:
		y_deadband_timer = 0.0
		y_deadbanded = true


func _update_hud(_delta):
	hp_bar.size.x = guy.HP
	strength_bar.size.x = guy.Energy * 100
	
	
func _update_bush_transparency():
	var bushes : Array[Node] = get_tree().get_nodes_in_group("Bush")
	for bush in bushes:
		bush.Transparent = bush.inhabitants.has(guy)


func _update_guy_hidden():
	var guys : Array[Node] = get_tree().get_nodes_in_group("Guy")
	for guy in guys:
		if guy == guy:
			pass
		else:
			guy.sprite.visible = can_see_through_all_concealments(guy)
		
		
func can_see_through_all_concealments(other_guy : CharacterBody2D) -> bool:
	for concealment in other_guy.Concealments:
		if concealment == null:
			continue
		elif not guy.Concealments.has(concealment):
			return false
	return true
		
