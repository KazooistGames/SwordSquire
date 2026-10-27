class_name GameplayHarness extends Node

'''
specifically responsible for mapping physical input to gameplay controls over a guy
'''

var guy : Guy = null

func _ready():
	guy = get_parent()
	assert(guy != null)

func _process(delta : float) -> void:
	assert(guy != null)
	_movement_inputs(delta)
	_combat_inputs(delta)
	if Input.is_action_just_pressed("Interact"):
		guy.interact()
			

func _movement_inputs(_delta : float) -> void:
	assert(guy != null)
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
	assert(guy != null)
	if Input.is_action_just_pressed("smash"):
		guy.charge()
	elif Input.is_action_just_released("smash"):
		guy.release()

		
