class_name Guy extends CharacterBody2D

const duck_duration := 0.1
const coyote_period := 0.10
const base_accel := 400
const base_speed := 75
const charge_timer_max := 1.0
const charge_timer_min := 0.25
const cooldown_period = 0.5
const base_energy_rate := 0.15
const base_jump_height = 24
const base_run_charge_period = 0.2

enum State{
	ready,
	charging,
	attacking,
	recovering,
	#sliding,
	dead
}

@export var Team := 0
@export var state : State = State.ready
@export var HP := 100
@export var Energy := 1.0
@export var left_right := 0
@export var Concealments : Array[Area2D] = []

@onready var sprite : FightingFrames = $FightingFrames
@onready var hitbox : Area2D = $FightingFrames/hitBox
@onready var hurtbox : Area2D = $FightingFrames/hurtBox

#var aerial := false

var real_speed := 60.0
@export var run_accel := 0.0
var facing_direction := 1
var facing_locked := false
var charge_timer := 0.0
var charge_marked_for_release := false #used when guy attempts to swing before min charge is met
var cooldown_timer := 0.0
var coyote_timer := 0.0
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
	state = State.ready
	
func _physics_process(delta : float) -> void:	

	if duck_debounce < duck_duration:
		duck_debounce += delta
		collision_mask = 1	
	else:
		collision_mask = 17
		
	_process_energy(delta)
	_process_movement(delta)		
	_animate_state()
	_process_state(delta)
	facing_locked = state != State.ready and state != State.charging
	if left_right != 0 and not facing_locked:
		facing_direction = left_right	


func _process_movement(delta : float) -> void:
	var target_real_speed = left_right * base_speed
	if state != State.ready:
		target_real_speed = 0
		run_accel = base_accel / 2
	elif left_right == 0 or sign(left_right) != sign(velocity.x):	
		run_accel = base_accel / 2
	elif run_charge_timer >= base_run_charge_period:		
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
		

	
func _animate_state():
	if HP <= 0:
		sprite.set_state('die')
		return	
	match(state):
		State.ready:
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
			elif run_charge_timer < base_run_charge_period:
				sprite.set_state('slide')
			else:
				sprite.set_state('run')
				var real_speed_ratio = abs(velocity.x) / base_speed
				sprite.playback_speed = real_speed_ratio
		State.charging:
			sprite.flip_h = facing_direction > 0
			if smash_attack:
				sprite.set_state('slash_windup')
			else:
				sprite.set_state('stab_windup')
		State.attacking:
			if smash_attack:
				sprite.set_state('slash')
			else:
				sprite.set_state('stab')
		State.recovering:
			if smash_attack:
				sprite.set_state('slash_recover')
			else:
				sprite.set_state('stab_recover')
	
	
func _process_state(delta : float) -> void:
	match state:		
		State.ready:
			if left_right == 0 and velocity.x == 0:
				run_charge_timer = 0.0
			elif sign(left_right) != sign(velocity.x):
				run_charge_timer = 0.0
			else:
				if run_charge_timer == 0:
					shove(Vector2.RIGHT * sign(left_right) * base_speed / 10)
				run_charge_timer += delta
		State.charging:
			charge_timer += delta	
			if charge_timer >= charge_timer_max:
				charge_timer = charge_timer_max 
				release()	
			elif charge_timer < charge_timer_min:
				pass
			elif charge_marked_for_release:
				release()			
			sprite.flip_h = facing_direction > 0	
		State.attacking:
			pass	
		State.recovering:
			cooldown_timer -= delta
			if cooldown_timer <= 0:
				ready()		


func _process_energy(delta) -> void:
	if state != State.ready:
		pass
	elif is_on_floor():
		var stationary_buff = lerp(2, 1, abs(left_right))
		var health_nerf = lerp(0.5, 1.0, HP / 100)
		Energy += delta * base_energy_rate * stationary_buff		
	Energy = clampf(Energy, 0.0, 1.0)
	

func jump() -> bool:
	if state == State.dead:
		return false
	elif coyote_timer < coyote_period:
		coyote_timer = coyote_period
		run_charge_timer = base_run_charge_period
		velocity.y = -sqrt(base_jump_height * 1960)
		jumped.emit()
		return true
	elif double_jump_charges > 0:
		velocity.y = -sqrt(base_jump_height * 1960)
		double_jump_charges -= 1
		sap(.15)
		jumped.emit()
		return true
	else:
		return false

func land():
	double_jump_charges = 1

	
func duck() -> bool:
	duck_debounce = 0.0
	return false
	
	
func charge() -> bool:
	if state == State.ready:
		sprite.playback_speed = 1.0
		state = State.charging
		cooldown_timer = 0.0
		charge_timer = 0.0
		smash_attack = left_right == 0
		return true	
	else:
		return false
	
	
func release() -> bool:
	if not state == State.charging:
		return false
	elif charge_timer < charge_timer_min:
		charge_marked_for_release = true
		return false	
	else:
		charge_marked_for_release = false
		state = State.attacking
		cooldown_timer = cooldown_period
		var charged_power = charge_timer / charge_timer_max	
		sap(charged_power * 0.5)
		if smash_attack:
			sprite.playback_speed = 1.0
			pass
			#sap(charged_power * 0.5)
		else:
			sprite.playback_speed = lerpf(1.0, 0.2, charged_power)
			var base_magnitude = base_speed * 2
			var impulse = Vector2(facing_direction, 0) * base_magnitude * sqrt(charged_power)
			shove(impulse)
		return true


func recover() -> bool:
	if state == State.attacking:
		sprite.playback_speed = 1.0
		state = State.recovering
		return true
	else:
		return false


func ready() -> bool:
	if state == State.recovering:
		sprite.playback_speed = 1.0
		state = State.ready
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
	if state == State.attacking:
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
		state = State.dead


func is_facing(object : Node2D) -> bool:
	var disposition = object.global_position - global_position
	return sign(disposition.x) == sign(facing_direction)
	
	
func turn_toward(object : Node2D):
	if left_right != 0:
		return	
	var x_disposition = object.global_position.x - global_position.x
	facing_direction = sign(x_disposition)
	
	
func sap(value : float):	
	if value > Energy:
		Energy = 0.0
	else:
		Energy -= value


func interact():
	var interactable_bodies = hurtbox.get_overlapping_bodies()
	for body in interactable_bodies:	
		if body.collision_layer & 512 >= 1:
			body.use(self)
			return

	
	
