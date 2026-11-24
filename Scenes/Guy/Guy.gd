class_name Guy extends CharacterBody2D

const MASK = SwordSquire.LAYER.TERRAIN + SwordSquire.LAYER.OBSTACLES + SwordSquire.LAYER.GUY
const DUCK_MASK = SwordSquire.LAYER.TERRAIN

const DUCK_DURATION := 0.1
const COYOTE_PERIOD := 0.1
const BASE_ACCEL := 300
const BASE_SPEED := 90
const RUN_CHARGE_BASE_PERIOD := 0.4
const CHARGE_TIMER_MAX := 0.75
const CHARGE_TIMER_MIN := 0.15
const COOLDOWN_PERIOD := 0.4
const POISE_BASE_RATE := 0.1
const POISE_BASE_COST := 0.2
const JUMP_BASE_HEIGHT := 30
const JUMP_MAGIC_NUMBER := 1960
const JUMP_MIN_CHARGE := 0.1
const JUMP_MAX_CHARGE := 0.5
const DUCK_BOOST := 1.0
const BASE_DOUBLE_JUMP_CHARGES := 1

enum Posture{
	weak = -1,
	normal = 0,
	strong = 1
}

enum Stance{
	ready,
	charging,
	attacking,
	recovering,
	jumping,
	ducking,
	dead
}

@export var Team := 0
@export var stance : Stance = Stance.ready
@export var HP := 100
@export var Poise := 1.0
@export var posture : Posture = Posture.strong
@export var left_right := 0
@export var Concealments : Array[Area2D] = []

@onready var frame_rig : FrameRig = $frameRig
@onready var interact_box : Area2D = $interactBox

#var aerial := false

var real_speed := 60.0
@export var effective_accel := 0.0
var facing_direction := 1
var facing_locked := false
var charge_timer := 0.0
var charge_marked_for_release := false #used when guy attempts to swing before min charge is met
var cooldown_timer := 0.0
var coyote_timer := 0.0
var jump_charge_timer := 0.0
var double_jump_charges : int = 1
var run_charge_timer := 0.0
var smash_attack := false
var wall_side := 0

var jump_latch := false :
	get():
		return jump_latch
	set(value):
		var rising = value and not jump_latch
		if not rising: 
			pass
		elif is_on_floor():
			charge_jump()
		elif is_wallhanging():
			wall_jump()
		else:
			double_jump()
			
		jump_latch = value
		
var request_duck := false

var effective_poise : float :
	get():
		match posture:
			Posture.weak:
				return 0.0
			Posture.normal:
				return 1.0
			Posture.strong:
				return 1.0
		return NAN	


signal died
signal jumped
signal fell

func _ready() -> void:
	frame_rig.finished.connect(_handle_animation_finished)
	frame_rig.set_state('ready')
	frame_rig.play()
	stance = Stance.ready
	
	
func _physics_process(delta : float) -> void:	
	_poise(delta)
	_movement(delta)		
	_state_transitions()
	_process_state(delta)


var target_speed := 0.0
func _movement(delta : float) -> void:
	
	#Coyote timer	
	if is_on_floor() or is_wallhanging():
		if coyote_timer >= COYOTE_PERIOD:
			land()		
		coyote_timer = 0
	else:
		if coyote_timer == 0.0:
			fell.emit()	
		coyote_timer += delta	
	
	target_speed = left_right * BASE_SPEED	
	
	if is_on_wall():		
		var collision : KinematicCollision2D = get_last_slide_collision()
		wall_side = 0 if collision == null else sign(-collision.get_normal().x)
	else:
		wall_side = 0
		
	# grounded movement
	if is_on_floor():
		if stance != Stance.ready: # doing somethingaw
			target_speed = 0
			effective_accel = BASE_ACCEL / 2.0
		elif left_right == 0 or sign(left_right) != sign(velocity.x): # pivot
			effective_accel = BASE_ACCEL		
		elif abs(velocity.x) > abs(target_speed):
			effective_accel = BASE_ACCEL / 2.0
		elif run_charge_timer >= RUN_CHARGE_BASE_PERIOD: # speeding up
			var speed_ratio = clampf(abs(velocity.x)/BASE_SPEED, 0.0, 1.0)
			effective_accel = lerpf(BASE_ACCEL, 0, pow(speed_ratio, 2))			
		else:
			target_speed = 0
			effective_accel = 0.0
	# aerial movement
	else:
		'''
		Orients on directional input instead of stance.
		Lends to more "veritacity" in the jump.
		The jump feels controlled while still carrying aerial momentum
		''' 
		velocity.y += 980 * delta	# gravity
		
		if is_wallhanging(): # grapple wall 
			#velocity.x = 0
			velocity.y = min(velocity.y, 0.0)

		effective_accel = BASE_ACCEL
		if left_right == 0:	# idle
			effective_accel = 0.0
		elif sign(left_right) != sign(velocity.x): # turning around
			pass
		elif abs(velocity.x) < BASE_SPEED: # speeding up
			pass
		else:
			effective_accel =  0.0
			
	var increment = effective_accel * delta
	velocity.x = move_toward(velocity.x, target_speed, increment)	
	move_and_slide()
	

func _state_transitions():
	if HP <= 0:
		frame_rig.set_state('die')
		return	
	match(stance):
		Stance.ready:
			if not is_on_floor():
				frame_rig.set_state('aerial')
			elif velocity.x == 0:
				frame_rig.set_state('ready')
			elif left_right == 0 or sign(left_right) != sign(velocity.x):
				frame_rig.set_state('slide')
			elif run_charge_timer < RUN_CHARGE_BASE_PERIOD:
				frame_rig.set_state('slide')
			else:
				frame_rig.set_state('run')
				var real_speed_ratio = abs(velocity.x) / BASE_SPEED
				frame_rig.playback_speed = real_speed_ratio
		Stance.charging:
			frame_rig.flip_h = facing_direction > 0
			if smash_attack:
				frame_rig.set_state('slash_windup')
			else:
				frame_rig.set_state('stab_windup')
		Stance.attacking:
			if smash_attack:
				frame_rig.set_state('slash')
			else:
				frame_rig.set_state('stab')
		Stance.recovering:
			if smash_attack:
				
				frame_rig.set_state('slash_recover')
			else:
				frame_rig.set_state('stab_recover')
		Stance.jumping:
			frame_rig.set_state('jump_charge')
		Stance.ducking:
			frame_rig.set_state('duck')


func _process_state(delta : float) -> void:
	'''
	non-movement state-specific code.
	'''
	facing_locked = true
	if facing_direction > 0:
		frame_rig.flip_h = true
	elif facing_direction < 0:
		frame_rig.flip_h = false
		
	match stance:		
		Stance.ready:
			facing_locked = false
			if left_right == 0 and velocity.x == 0:
				run_charge_timer = 0.0
			elif sign(left_right) != sign(velocity.x) and left_right != 0:
				run_charge_timer = 0.0
			else: # weird way to get the edge, but this is 
				#if run_charge_timer == 0 and is_on_floor():
					#var direction = Vector2.RIGHT * sign(left_right)
					#var magnitude = BASE_SPEED / 10
					#shove( direction * magnitude)
				run_charge_timer += delta * (1 + effective_poise)
				
		Stance.charging:
			charge_timer += delta	
			if charge_timer >= CHARGE_TIMER_MAX:
				charge_timer = CHARGE_TIMER_MAX 
				release()	
			elif charge_timer < CHARGE_TIMER_MIN:
				pass
			elif charge_marked_for_release:
				release()			
			frame_rig.flip_h = facing_direction > 0	
			
		Stance.attacking:
			pass	
			
		Stance.recovering:
			cooldown_timer -= delta * (0.5 + effective_poise/2.0)
			if cooldown_timer <= 0:
				ready()		
				
		Stance.jumping:
			jump_charge_timer += delta
			facing_locked = false
			if jump_charge_timer >= JUMP_MAX_CHARGE:
				release_jump()
			elif jump_latch:
				pass
			elif jump_charge_timer >= JUMP_MIN_CHARGE:
				release_jump()
			
			
	if left_right == 0 or facing_locked:
		pass
	elif is_wallhanging():
		facing_direction = -left_right	
	elif is_on_floor():
		facing_direction = left_right	
	elif stance == Stance.ready:
		facing_direction = sign(velocity.x)
	else:
		facing_direction = left_right


func _poise(delta) -> void:
	if stance != Stance.ready:
		pass
	elif is_on_floor():
		var stationary_buff : float = 2 - abs(left_right)
		var increment : float = delta * POISE_BASE_RATE * stationary_buff		
		Poise += increment
	Poise = clampf(Poise, 0.0, 1.0)
	
	if Poise == 1:
		posture = Posture.strong
	elif Poise == 0.0:
		posture = Posture.weak
	elif posture != Posture.weak:
		posture = Posture.normal


func charge_jump() -> bool: #returns true on successful transition to jump charge
	if stance != Stance.ready:
		return false
	elif is_on_floor():
		frame_rig.playback_speed = 1.0
		stance = Stance.jumping
		return true
	else:
		return false	


func release_jump() -> bool: #returns true on successful transition to jumping
	if stance != Stance.jumping:
		return false
	elif jump_charge_timer < JUMP_MIN_CHARGE:
		return false
	elif coyote_timer < COYOTE_PERIOD:
		coyote_timer = COYOTE_PERIOD
		var charge_range = JUMP_MAX_CHARGE - JUMP_MIN_CHARGE
		var charge_delta = jump_charge_timer - JUMP_MIN_CHARGE
		var effective_charge = charge_delta/charge_range
		var jump_scalar = 1 + clampf(effective_charge, 0, 1.0)
		velocity.y = -sqrt(JUMP_BASE_HEIGHT * JUMP_MAGIC_NUMBER * jump_scalar) 
		if effective_charge >= 1.0:
			velocity.x = left_right * BASE_SPEED
		stance = Stance.ready
		jump_charge_timer = 0.0
		jumped.emit()
		return true
	else:
		stance = Stance.ready
		jump_charge_timer = 0.0
		return false


func wall_jump() -> bool:
	if is_wallhanging():
		velocity.y = -sqrt(JUMP_BASE_HEIGHT * 1960)
		velocity.x = -wall_side * BASE_SPEED
		double_jump_charges
		return true
	else:
		return false

func double_jump() -> bool:
	if is_on_floor():
		return false
	elif is_on_wall():
		return false
	elif double_jump_charges <= 0:
		return false
	else:
		velocity.y = -sqrt(JUMP_BASE_HEIGHT * 1960)
		double_jump_charges -= 1
		return true


func land():
	double_jump_charges = BASE_DOUBLE_JUMP_CHARGES


func dash() -> void:
	var direction = Vector2(left_right, 0)
	shove(direction * BASE_SPEED * DUCK_BOOST)
	sap(POISE_BASE_COST)

func duck() -> bool:
	if stance == Stance.recovering or stance == Stance.attacking or stance == Stance.ducking:
		return false
	stance = Stance.ducking
	frame_rig.playback_speed = 1.0
	if left_right != 0:
		dash()
	else:
		collision_mask = DUCK_MASK
	return true
	
	
func release_duck() -> bool:
	if stance != Stance.ducking:
		return false
	if frame_rig.playing:
		return false
	elif (abs(velocity.x) > lerp(0, BASE_SPEED, effective_poise)):
		return false
		
	collision_mask = MASK	
	stance = Stance.ready
	return true
	
	
func charge() -> bool:
	if stance == Stance.ready:
		frame_rig.playback_speed = 1.0
		stance = Stance.charging
		cooldown_timer = 0.0
		charge_timer = 0.0
		smash_attack = left_right == 0
		return true	
	else:
		return false
	
	
func release() -> bool:
	if not stance == Stance.charging:
		return false
	elif charge_timer < CHARGE_TIMER_MIN:
		charge_marked_for_release = true
		return false	
	else:
		charge_marked_for_release = false
		stance = Stance.attacking
		cooldown_timer = COOLDOWN_PERIOD
		var charged_power = charge_timer / CHARGE_TIMER_MAX	
		sap(POISE_BASE_COST)
		if smash_attack:
			frame_rig.playback_speed = lerpf(1.0, 2.0, charged_power)
		else:
			#TODO: make the shove be an assertion of velocity, not additive?
			frame_rig.playback_speed = lerpf(1.0, 0.25, charged_power)
			var base_magnitude = BASE_SPEED * 2.0
			var impulse = Vector2(facing_direction, 0) * base_magnitude * sqrt(charged_power)
			shove(impulse)
		return true


func recover() -> bool:
	if stance == Stance.attacking:
		stance = Stance.recovering
		frame_rig.playback_speed = 1.0
		return true	
	else:
		return false


func ready() -> bool:
	if stance == Stance.recovering:
		frame_rig.playback_speed = 1.0
		stance = Stance.ready
		charge_timer = 0.0
		return true
	else:
		return false
	
	
func _handle_hit(guy : CharacterBody2D):
	var power = sqrt(charge_timer/CHARGE_TIMER_MAX) * 120
	var impulse = Vector2(facing_direction, 0) * power
	guy.shove(impulse)
	guy.damage(charge_timer/CHARGE_TIMER_MAX * 100)
	
	
func _handle_parry(guy : CharacterBody2D):
	var impulse = Vector2(facing_direction, 0) * 72
	guy.shove(impulse)


func _handle_animation_finished():
	if stance == Stance.attacking:
		recover()	
	
		
func check_sprite_collision(coordinates : Vector2, bounds : Vector2, offset : Vector2 = Vector2.ZERO) -> bool:
	var disposition : Vector2 = coordinates - global_position
	var pixel_coord : Vector2
	var bound_coord : Vector2 = Vector2.ZERO
	for y in range(-bounds.y / 2.0, bounds.y / 2.0):
		bound_coord.y = y
		for x in range(-bounds.x / 2.0, bounds.x / 2.0):
			bound_coord.x = x
			pixel_coord = disposition + bound_coord + offset
			if frame_rig.is_pixel_opaque(pixel_coord):
				return true	
	return false


func shove(impulse : Vector2) -> void:
	if sign(velocity.x) == sign(impulse.x):
		velocity.x += impulse.x
	else:
		velocity.x = impulse.x
			
	assert(not is_nan(velocity.x))
	
			
func damage(value : int) -> void:
	HP -= value
	if HP <= 0:
		died.emit()
		stance = Stance.dead


func is_facing(object : Node2D) -> bool:
	var disposition = object.global_position - global_position
	return sign(disposition.x) == sign(facing_direction)
	
	
func turn_toward(object : Node2D):
	if left_right != 0:
		return	
	var x_disposition = object.global_position.x - global_position.x
	facing_direction = sign(x_disposition)
	
	
func sap(value : float):	
	if value > Poise:
		Poise = 0.0
	else:
		Poise -= value


func interact():
	var interactable_bodies = interact_box.get_overlapping_bodies()
	for body in interactable_bodies:	
		if body.collision_layer & 512 >= 1:
			body.use(self)
			return

	
func is_wallhanging() -> bool:
	return wall_side * left_right > 0 and is_on_wall_only()
