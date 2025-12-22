extends RigidBody2D

const energy := 50

func _ready():
	
	freeze = true
	

func smack(impulse : Vector2):
	
	freeze = false
	apply_central_impulse(impulse)
	apply_torque_impulse(impulse.length())
	
	
func use(guy : CharacterBody2D):
	
	guy.Energy = clampf(guy.Energy + energy, 0, 100)
	queue_free()
