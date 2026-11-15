extends Area2D

var colliders : Array[CollisionShape2D] = []
var box_frames : Array[BoxFrames] = []

@onready var rig : FrameRig = get_parent()

func _physics_process(delta: float) -> void:
	var active_frame_index = rig.current_frame_index - rig.frame_sheet.first_i
	for collider : CollisionShape2D in colliders:
		var box_frames : BoxFrames = box_frames[colliders.find(collider)]
		set_collider_frame(collider, box_frames, active_frame_index)
	

func load_sheet(sheet : FrameSheet):
	
	for col in colliders:
		col.queue_free()
	colliders.clear()
	box_frames = sheet.get_children().filter(
		func(x): return x is BoxFrames and x.type == BoxFrames.Type.hurt)
		
	for box_frames in box_frames:
		var new_col = CollisionShape2D.new()
		new_col.shape = CapsuleShape2D.new()
		add_child(new_col)
	

func set_collider_frame(collider : CollisionShape2D, frames : BoxFrames, active_frame_index : int):
	var frame_offset = frames.offset.get(active_frame_index)
	var frame_radius = frames.radius.get(active_frame_index)
	var frame_height = frames.height.get(active_frame_index)
	
	if frame_offset != null:
		collider.position = frame_offset
	if frame_radius != null:
		collider.shape.radius = frame_radius
	if frame_height != null:
		collider.shape.height = frame_height
	
