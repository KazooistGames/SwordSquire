@tool
class_name FrameRig
extends Sprite2D

@export var playing := false :
	set(value):
		playing = value
		if params == null:
			return
		elif playing and current_frame_index == params.last_i:
			current_frame_index = params.first_i
@export var playback_speed = 1.0
@export var current_frame_index := 0
@export var frame_timer := 0.0



@export var params : FrameParams :
	get:
		return params
	set(value):
		if not value is FrameParams:
			return
		elif value != null and value != params:
			params = value
			play()			
				
signal started()
signal looped()
signal finished()
	
func _ready() -> void:
	params = $ready #guarantees it isnt null on load..

func _physics_process(delta: float) -> void:
	if params == null:
		push_warning("%s params null" % self)
		return
		
	if not playing:
		frame_timer = 0
	else:
		frame_timer += delta * playback_speed
		var frame_period : float = 1.0 / params.fps
		if frame_timer >= frame_period:
			frame_timer -= frame_period
			_get_next_frame()		

	current_frame_index = clampi(current_frame_index, params.first_i, params.last_i)
	_render_current_frame()


func _get_next_frame():
	if current_frame_index < params.last_i:
		current_frame_index += 1	
	elif params.loop:
		current_frame_index = params.first_i
		looped.emit()	
	else:
		stop()


func _render_current_frame():
	if params.sheet != null:	#get exact frame texture based on active state and offset coordinates
		texture = params.sheet
		var x = params.tex_size.x * current_frame_index
		var y = 0
		var w = params.tex_size.x
		var h = params.tex_size.y
		region_rect = Rect2(x, y, w, h)
	
	var frame_number : int = current_frame_index - params.first_i
	var x_dir = -1 if flip_h else 1
	var y_dir = -1 if flip_v else 1

		
		
func play():
	started.emit()
	texture = params.sheet
	current_frame_index = params.first_i
	playing = true
	
func stop():
	finished.emit()
	playing = false
	
	
func set_state(state_name : String):
	if params == null:
		pass
	elif state_name == params.name:
		return
		
	var children = get_children()
	for child in children:
		if not child is FrameParams:
			pass
		elif child.name == state_name:
			frame_timer = 0
			params = child
	
