extends Camera2D

const base_x_speed := 0.25
const base_y_speed := 0.25
const y_range := 50


@export var target_position := Vector2(0, 0)

@onready var hud = $HUD
@onready var hp_bar : ColorRect = $HUD/hp_bar
@onready var strength_bar : ColorRect = $HUD/strength_bar
@onready var fov_light : PointLight2D = $PointLight2D

var x_target := 0.0
var y_target := 0.0
var y_offset := -6.0
var y_deadbanded := false
var y_deadband_timer := 0.0

var guy : Guy = null 


func _process(delta : float) -> void:
	hud.visible = guy != null
	if guy != null:
		target_position = guy.global_position
		track_guy_horizontally(delta)
		track_guy_vertically(delta)
		fov_light.global_position = guy.global_position
		_update_bush_transparency()
		_update_guy_hidden()	
		_update_hud(delta)
		
		
func _physics_process(delta):
	if guy != null:
		track_guy_horizontally(delta)
		track_guy_vertically(delta)
	

func track_guy_horizontally(delta):
	assert(guy != null)
	x_target = guy.global_position.x
	var offset_from_target : float = abs(x_target - global_position.x)
	var speed = base_x_speed + offset_from_target / 20.0
	global_position.x = move_toward(global_position.x, target_position.x, speed)


func track_guy_vertically(delta):
	assert(guy != null)
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
	assert(guy != null)
	hp_bar.size.x = guy.HP
	strength_bar.size.x = guy.Energy * 100
	
	
func _update_bush_transparency():
	assert(guy != null)
	var bushes : Array[Node] = get_tree().get_nodes_in_group("Bush")
	for bush in bushes:
		bush.Transparent = bush.inhabitants.has(guy)


func _update_guy_hidden():
	assert(guy != null)
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
		
