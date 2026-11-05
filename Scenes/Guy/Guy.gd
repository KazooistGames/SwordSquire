class_name Guy extends CharacterBody2D

const MASK = SwordSquire.LAYER.TERRAIN + SwordSquire.LAYER.OBSTACLES + SwordSquire.LAYER.GUY
const DUCK_MASK = SwordSquire.LAYER.TERRAIN

const duck_duration := 0.1
const coyote_period := 0.10
const base_accel := 400
const base_speed := 75
const RUN_CHARGE_BASE_PERIOD = 0.25
const charge_timer_max := 0.75
const charge_timer_min := 0.25
const cooldown_period = 0.5
const base_poise_rate := 0.15
const JUMP_BASE_HEIGHT = 24
const JUMP_BASE_PERIOD = 0.75
const JUMP_MAX_CHARGE = 1.0

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
	dead
}

@export var Team := 0
@export var stance : Stance = Stance.ready
@export var HP := 100
@export var Poise := 1.0
@export var posture : Posture = Posture.strong
@export var left_right := 0
@export var Concealments : Array[Area2D] = []

@onready var sprite : FightingFrames = $FightingFrames
@onready var hitbox : Area2D = $FightingFrames/hitBox
@onready var hurtbox : Area2D = $FightingFrames/hurtBox

#var aerial := false

var real_speed := 60.0
var run_accel := 0.0
var facing_direction := 1
var facing_locked := false
var charge_timer := 0.0
var charge_marked_for_release := false #used when guy attempts to swing before min charge is met
var cooldown_timer := 0.0
var coyote_timer := 0.0
var jump_charge_timer := 0.0
var duck_debounce := 0.0
var double_jump_charges : int = 1
var run_charge_timer := 0.0
var smash_attack := false

signal died
signal jumped
signal fell


func _ready() -> void:
	sprite.finished.connect(_handle_animation_finished)
	sprite.play()
	sprite.set_state('stance')
	stance = Stance.ready
	
	
func _physics_process(delta : float) -> void:	
	if duck_debounce < duck_duration:
		duck_debounce += delta
		collision_mask = DUCK_MASK
	else:
		collision_mask = MASK
		
	_process_poise(delta)
	_process_movement(delta)		
	_animate_stance()
	_process_stance(delta)
	facing_locked = stance != Stance.ready and stance != Stance.charging
	if left_right != 0 and not facing_locked:
		facing_direction = left_right	


func _process_movement(delta : float) -> void:
	var target_real_speed = left_right * base_speed
	if stance != Stance.ready:
		target_real_speed = 0
		run_accel = base_accel / 2
	elif left_right == 0 or sign(left_right) != sign(velocity.x):	
		run_accel = base_accel / 2
	elif run_charge_timer >= RUN_CHARGE_BASE_PERIOD:		
		var speed_ratio = clampf(abs(velocity.x)/base_speed, 0.0, 1.0)
		run_accel = lerpf(base_accel, 0, pow(speed_ratio, 2))	
	else:
		target_real_speed = 0
		run_accel = 0.0
			
	if not is_on_floor():
		velocity.y += 980 * delta		
		run_accel /= 2	
		
	velocity.x = move_toward(velocity.x, target_real_speed, run_accel * delta)	
	move_and_slide()	
	
	#Coyote timer
	if is_on_floor():
		if coyote_timer >= coyote_period:
			land()		
		coyote_timer = 0
	else:
		if coyote_timer == 0.0:
			fell.emit()	
		coyote_timer += delta
		

func _animate_stance():
	if HP <= 0:
		sprite.set_state('die')
		return	
	match(stance):
		Stance.ready:
			if facing_direction > 0:
				sprite.flip_h
			elif facing_direction < 0:
				sprite.flip_h = false
			sprite.flip_h = facing_direction > 0
			if not is_on_floor():
				sprite.set_state('stance')
			elif velocity.x == 0:
				sprite.set_state('stance')
			elif left_right == 0 or sign(left_right) != sign(velocity.x):
				sprite.set_state('slide')
			elif run_charge_timer < RUN_CHARGE_BASE_PERIOD:
				sprite.set_state('slide')
			else:
				sprite.set_state('run')
				var real_speed_ratio = abs(velocity.x) / base_speed
				sprite.playback_speed = real_speed_ratio
		Stance.charging:
			sprite.flip_h = facing_direction > 0
			if smash_attack:
				sprite.set_state('slash_windup')
			else:
				sprite.set_state('stab_windup')
		Stance.attacking:
			if smash_attack:
				sprite.set_state('slash')
			else:
				sprite.set_state('stab')
		Stance.recovering:
			if smash_attack:
				sprite.set_state('slash_recover')
			else:
				sprite.set_state('stab_recover')
		Stance.jumping:
			sprite.set_state('jump_charge')
	
	
func _process_stance(delta : float) -> void:
	match stance:		
		Stance.ready:
			if left_right == 0 and velocity.x == 0:
				run_charge_timer = 0.0
			elif sign(left_right) != sign(velocity.x) and left_right != 0:
				run_charge_timer = 0.0
			else:
				if run_charge_timer == 0:
					shove(Vector2.RIGHT * sign(left_right) * base_speed / 10)
				run_charge_timer += delta
		Stance.charging:
			charge_timer += delta	
			if charge_timer >= charge_timer_max:
				charge_timer = charge_timer_max 
				release()	
			elif charge_timer < charge_timer_min:
				pass
			elif charge_marked_for_release:
				release()			
			sprite.flip_h = facing_direction > 0	
		Stance.attacking:
			pass	
		Stance.recovering:
			cooldown_timer -= delta
			if cooldown_timer <= 0:
				ready()		
		Stance.jumping:
			jump_charge_timer += delta


func _process_poise(delta) -> void:
	if stance != Stance.ready:
		pass
	elif is_on_floor():
		var stationary_buff = lerp(2, 1, abs(left_right))
		Poise += delta * base_poise_rate * stationary_buff		
	Poise = clampf(Poise, 0.0, 1.0)
	
	if Poise == 1:
		posture = Posture.strong
	elif Poise == 0.0:
		posture = Posture.weak
	elif posture != Posture.weak:
		posture = Posture.normal
	
	
func charge_jump() -> bool:
	if stance != Stance.ready:
		return false
	elif coyote_timer < coyote_period:
		sprite.playback_speed = 1.0
		stance = Stance.jumping
		return true
	else:
		return false

func release_jump() -> bool:
	if stance != Stance.jumping:
		return false
	elif coyote_timer < coyote_period:
		coyote_timer = coyote_period
		run_charge_timer = RUN_CHARGE_BASE_PERIOD # allows for acceleration out of jump
		var jump_charge = 1 + clampf(jump_charge_timer, 0, JUMP_MAX_CHARGE)
		velocity.y = -sqrt(JUMP_BASE_HEIGHT * 1960) * jump_charge
		stance = Stance.ready
		jump_charge_timer = 0.0
		jumped.emit()
		return true
	#elif double_jump_charges > 0:
		#velocity.y = -sqrt(JUMP_BASE_HEIGHT * 1960)
		#double_jump_charges -= 1
		#sap(.15)
		#jumped.emit()
		#return true
	else:
		return false


func land():
	double_jump_charges = 1

	
func duck() -> bool:
	duck_debounce = 0.0
	return false
	
	
func charge() -> bool:
	if stance == Stance.ready:
		sprite.playback_speed = 1.0
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
	elif charge_timer < charge_timer_min:
		charge_marked_for_release = true
		return false	
	else:
		charge_marked_for_release = false
		stance = Stance.attacking
		cooldown_timer = cooldown_period
		var charged_power = charge_timer / charge_timer_max	
		sap(charged_power * 0.5)
		if smash_attack:
			sprite.playback_speed = lerpf(1.0, 2.0, charged_power)
		else:
			sprite.playback_speed = lerpf(1.0, 0.25, charged_power)
			var base_magnitude = base_speed * 2.0
			var impulse = Vector2(facing_direction, 0) * base_magnitude * sqrt(charged_power)
			shove(impulse)
		return true


func recover() -> bool:
	if stance == Stance.attacking:
		sprite.playback_speed = 1.0
		stance = Stance.recovering
		return true
	else:
		return false


func ready() -> bool:
	if stance == Stance.recovering:
		sprite.playback_speed = 1.0
		stance = Stance.ready
		charge_timer = 0.0
		return true
	else:
		return false
	
	
func _handle_hit(guy : CharacterBody2D):
	var power = sqrt(charge_timer/charge_timer_max) * 120
	var impulse = Vector2(facing_direction, 0) * power
	guy.shove(impulse)
	guy.damage(charge_timer/charge_timer_max * 100)
	
	
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
			if sprite.is_pixel_opaque(pixel_coord):
				return true	
	return false


func shove(impulse : Vector2) -> void:
	if sign(velocity.x) == sign(impulse.x):
		velocity.x += impulse.x
	else:
		velocity.x = impulse.x
			
	if is_nan(velocity.x):
		print("wtf")
	
			
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
	var interactable_bodies = hurtbox.get_overlapping_bodies()
	for body in interactable_bodies:	
		if body.collision_layer & 512 >= 1:
			body.use(self)
			return

	
	
