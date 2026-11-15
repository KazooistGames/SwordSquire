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
				
@export var hurt_sheets : Array[BoxSheet]				
@export var hit_sheets : Array[BoxSheet]				
				
signal started()
signal looped()
signal finished()
	
@onready var hitbox = $hitBox
@onready var hurtbox = $hurtBox
	

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

func _simulate_current_frame():
	var active_frame_index = current_frame_index - frame_sheet.first_i
	for collider : CollisionShape2D in hurtbox.colliders:
		var box_sheet : BoxSheet = hurt_sheets[hurtbox.colliders.find(collider)]
		set_collider_frame(collider, box_sheet, active_frame_index)
		
		
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
			load_box_frames(frame_sheet)
			break
	
	
func load_box_frames(sheet : FrameSheet):
	for col in hurtbox.colliders:
		col.queue_free()
		hurtbox.colliders.clear()
		hurt_sheets = sheet.get_children().filter(
			func(x): return x is BoxSheet and x.type == BoxSheet.Type.hurt)
			
		for frame in hurt_sheets:
			var new_col = CollisionShape2D.new()
			new_col.shape = CapsuleShape2D.new()
			add_child(new_col)
			
			
func set_collider_frame(collider : CollisionShape2D, frames : BoxSheet, active_frame_index : int):
	var frame_offset = frames.offset.get(active_frame_index)
	var frame_radius = frames.radius.get(active_frame_index)
	var frame_height = frames.height.get(active_frame_index)
	
	if frame_offset != null:
		collider.position = frame_offset
	if frame_radius != null:
		collider.shape.radius = frame_radius
	if frame_height != null:
		collider.shape.height = frame_height	
