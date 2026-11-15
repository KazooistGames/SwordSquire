@tool
class_name FrameRig
extends Sprite2D

@export var playing := false :
	set(value):
		playing = value
		if frame_sheet == null:
			return
		elif playing and current_frame_index == frame_sheet.last_i:
			current_frame_index = frame_sheet.first_i
@export var playback_speed = 1.0
@export var current_frame_index := 0
@export var frame_timer := 0.0



@export var frame_sheet : FrameSheet :
	get:
		return frame_sheet
	set(value):
		if not value is FrameSheet:
			return
		elif value != null and value != frame_sheet:
			frame_sheet = value
			play()			
				
signal started()
signal looped()
signal finished()
	
@onready var hit_box = $hitBox
@onready var hurt_box = $hurtBox
	

func _ready() -> void:
	frame_sheet = $ready #guarantees it isnt null on load..

func _physics_process(delta: float) -> void:
	if frame_sheet == null:
		return
		
	if not playing:
		frame_timer = 0
	else:
		frame_timer += delta * playback_speed
		var frame_period : float = 1.0 / frame_sheet.fps
		if frame_timer >= frame_period:
			frame_timer -= frame_period
			_get_next_frame()		

	current_frame_index = clampi(current_frame_index, frame_sheet.first_i, frame_sheet.last_i)
	_render_current_frame()


func _get_next_frame():
	if current_frame_index < frame_sheet.last_i:
		current_frame_index += 1	
	elif frame_sheet.loop:
		current_frame_index = frame_sheet.first_i
		looped.emit()	
	else:
		stop()


func _render_current_frame():
	if frame_sheet.sheet != null:	#get exact frame texture based on active state and offset coordinates
		texture = frame_sheet.sheet
		var x = frame_sheet.tex_size.x * current_frame_index
		var y = 0
		var w = frame_sheet.tex_size.x
		var h = frame_sheet.tex_size.y
		region_rect = Rect2(x, y, w, h)
	
	#var frame_number : int = current_frame_index - sheet.first_i
	#var x_dir = -1 if flip_h else 1
	#var y_dir = -1 if flip_v else 1

		
		
func play():
	started.emit()
	texture = frame_sheet.sheet
	current_frame_index = frame_sheet.first_i
	playing = true
	
func stop():
	finished.emit()
	playing = false
	
	
func set_state(state_name : String):
	if frame_sheet == null:
		pass
	elif state_name == frame_sheet.name:
		return
		
	var children = get_children()
	for child in children:
		if not child is FrameSheet:
			pass
		elif child.name == state_name:
			frame_timer = 0
			frame_sheet = child
			
			#TODO: set colliders for hitbox/hurtbox as per state
			
	
