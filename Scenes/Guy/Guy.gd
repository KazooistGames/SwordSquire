class_name Guy extends CharacterBody2D

const duck_duration := 0.1
const coyote_period := 0.10
const base_accel := 220
const base_speed := 75
const charge_timer_max := 1.0
const charge_timer_min := 0.20
const cooldown_period = 0.5
const base_energy_rate := 0.15
const base_jump_height = 24

enum State{
	ready,
	charging,
	attacking,
	recovering,
	sliding,
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
	
	if state == State.sliding:
		run_accel = base_accel /2
	elif state == State.ready:
		var speed_ratio = clampf(abs(velocity.x)/base_speed, 0, 1)
		var speed_nerf = max(pow(1.0 - speed_ratio, 1.5), 0.0)
		run_accel = base_accel * speed_nerf		
		var energy_nerf = lerpf(0.5, 1.0, Energy)
		target_real_speed = left_right * base_speed * energy_nerf
	else:
		target_real_speed = 0
		run_accel = base_accel / 2
	
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
		#aerial = coyote_timer >= coyote_period
		coyote_timer += delta
		

	
func _animate_state():
	if HP <= 0:
		sprite.set_state('die')
		return	
	sprite.playback_speed = 1.0
	match(state):
		State.ready:
			if facing_direction > 0:
				sprite.flip_h
			elif facing_direction <0:
				sprite.flip_h = false
			sprite.flip_h = facing_direction > 0
			if not is_on_floor():
				sprite.set_state('stance')
			elif velocity.x == 0:
				sprite.set_state('stance')
			else:
				sprite.set_state('run')
				var real_speed_ratio = abs(velocity.x) / base_speed
				sprite.playback_speed = real_speed_ratio
		State.charging:
			sprite.flip_h = facing_direction > 0
			sprite.set_state('slash_windup')
		State.attacking:
			sprite.set_state('slash')
		State.recovering:
			sprite.set_state('slash_recover')
		State.sliding:
			sprite.set_state('slide')
	
	
func _process_state(delta : float) -> void:
	match state:
		State.ready:
			if velocity.x != 0 and sign(velocity.x) != sign(left_right):
				state = State.sliding						
		State.charging:
			charge_timer += delta	
			if charge_timer >= charge_timer_max:
				charge_timer = charge_timer_max 
				release()				
			elif charge_marked_for_release:
				release()			
			sprite.flip_h = facing_direction > 0	
		State.attacking:
			pass	
		State.recovering:
			cooldown_timer -= delta
			if cooldown_timer <= 0:
				ready()		
		State.sliding:	 
			if velocity.x == 0:
				state = State.ready
			elif sign(velocity.x) == sign(left_right):
				state = State.ready


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
		#aerial = true
		coyote_timer = coyote_period
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
	#aerial = false
	double_jump_charges = 1

		
	
func duck() -> bool:
	duck_debounce = 0.0
	return false
	
func charge() -> bool:
	if state == State.ready:
		state = State.charging
		cooldown_timer = 0.0
		charge_timer = 0.0
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
		var energy_nerf = lerpf(2.0, 1.0, Energy)
		cooldown_timer = cooldown_period * energy_nerf
		var charge_power = charge_timer / charge_timer_max
		sap(charge_power * .30)
		var impulse = Vector2(facing_direction, 0) * charge_power * 100
		shove(impulse)
		return true

func recover() -> bool:
	if state == State.attacking:
		state = State.recovering
		return true
	else:
		return false

func ready() -> bool:
	if state == State.recovering:
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
		#var diff = value - Energy
		Energy = 0.0
		#damage(diff)
	else:
		Energy -= value

func interact():
	var interactable_bodies = hurtbox.get_overlapping_bodies()
	for body in interactable_bodies:	
		if body.collision_layer & 512 >= 1:
			body.use(self)
			return

	
	
