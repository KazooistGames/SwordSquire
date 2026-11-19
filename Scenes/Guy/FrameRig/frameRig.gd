@tool
class_name FrameRig
extends Sprite2D

@export var playing := false :
	set(value):
		playing = value
		if sheet == null:
			return
		elif playing and current_frame_index == sheet.last_i:
			current_frame_index = sheet.first_i
			
@export var playback_speed = 1.0
@export var current_frame_index := 0
@export var frame_timer := 0.0



@export var sheet : FrameSheet :
	get:
		return sheet
	set(value):
		sheet = value	
		if sheet != null:
			frame_timer = 0
			load_box_frames(sheet)
			play()		
				
		
#@export var hurt_sheets : Array[BoxSheet]				
#@export var hit_sheets : Array[BoxSheet]				
				
signal started()
signal looped()
signal finished()
	
@onready var hitbox : HitBox = $hitBox
@onready var hurtbox : HurtBox = $hurtBox
@onready var guy : Guy = get_parent()

func _ready() -> void:
	sheet = $ready #guarantees it isnt null on load..

func _physics_process(delta: float) -> void:
	print(hurtbox.colliders.size())
	if sheet == null:
		return
		
	if not playing:
		frame_timer = 0
	else:
		frame_timer += delta * playback_speed
		var frame_period : float = 1.0 / sheet.fps
		if frame_timer >= frame_period:
			frame_timer -= frame_period
			_get_next_frame()		

	current_frame_index = clampi(current_frame_index, sheet.first_i, sheet.last_i)
	_render_current_frame()
	_simulate_current_frame()


func _get_next_frame():
	if current_frame_index < sheet.last_i:
		current_frame_index += 1	
	elif sheet.loop:
		current_frame_index = sheet.first_i
		looped.emit()	
	else:
		stop()


func _render_current_frame():
	if sheet.texture != null:	#get exact frame texture based on active state and offset coordinates
		texture = sheet.texture
		var x = sheet.tex_size.x * current_frame_index
		var y = 0
		var w = sheet.tex_size.x
		var h = sheet.tex_size.y
		region_rect = Rect2(x, y, w, h)


func _simulate_current_frame():
	var active_frame_index = current_frame_index - sheet.first_i
	if hurtbox != null:
		for collider : CollisionShape2D in hurtbox.colliders:
			var box_sheet : BoxSheet = sheet.hurt_frames[hurtbox.colliders.find(collider)]
			set_collider_frame(collider, box_sheet, active_frame_index)
	if hitbox != null:
		for collider : CollisionShape2D in hitbox.colliders:
			var box_sheet : BoxSheet = sheet.hit_frames[hitbox.colliders.find(collider)]
			set_collider_frame(collider, box_sheet, active_frame_index)	
		
func play():
	started.emit()
	texture = sheet.texture
	current_frame_index = sheet.first_i
	playing = true
	
func stop():
	finished.emit()
	playing = false
	
	
func set_state(state_name : String):
	if sheet == null:
		pass
	elif state_name == sheet.name:
		return
		
	var children = get_children()
	for child in children:
		if not child is FrameSheet:
			pass
		elif child.name == state_name:
			sheet = child
			break
	
	
func load_box_frames(box_frames : Array[BoxSheet], box : Area2D):
	assert(box != null)
	var colliders = box.get_children().filter(func(x): x is CollisionShape2D)
	while(colliders.size() < box_frames.size()):
		var new_col = CollisionShape2D.new()
		new_col.shape = CapsuleShape2D.new()
		colliders.append(new_col)
		box.add_child(new_col)
	while(colliders.size() > box_frames.size()):
		colliders.pop_back().queue_free()

			
			
func set_collider_frame(collider : CollisionShape2D, frames : BoxSheet, active_frame_index : int):
	# uses ternaries as null coalescion to avoid editor error spam
	var frame_offset = frames.offset[active_frame_index] if active_frame_index >= 0 and active_frame_index < frames.offset.size() else null
	var frame_radius = frames.radius[active_frame_index] if active_frame_index >= 0 and active_frame_index < frames.radius.size() else null
	var frame_height = frames.height[active_frame_index] if active_frame_index >= 0 and active_frame_index < frames.height.size() else null
	
	if frame_offset != null:
		frame_offset.x *= -guy.facing_direction 
		collider.position = frame_offset
	if frame_radius != null:
		collider.shape.radius = frame_radius
	if frame_height != null:
		collider.shape.height = frame_height	
