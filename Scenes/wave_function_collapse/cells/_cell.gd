class_name Cell extends Resource

const cell_size := 32

@export var tiles: Array[PackedScene]

enum SocketType{
	sky,
	dirt,
	cave
	}

@export var _up: Array[SocketType]
@export var _down: Array[SocketType]
@export var _left: Array[SocketType]
@export var _right: Array[SocketType]

enum Orientation{
	default,
	flipped_h,
	flipped_v,
	rotated_cw,
	rotated_ccw
}

var orientation : Orientation
var collapsed := false :
	get: return collapsed

var Up: Array[SocketType]:
	get:
		match orientation:
			Orientation.flipped_h: return _up
			Orientation.flipped_v: return _down
			Orientation.rotated_cw: return _left
			Orientation.rotated_ccw: return _right
			_: return _up

var Down: Array[SocketType]:
	get:
		match orientation:
			Orientation.flipped_h: return _down
			Orientation.flipped_v: return _up
			Orientation.rotated_cw: return _right
			Orientation.rotated_ccw: return _left
			_: return _down

var Left: Array[SocketType]:
	get:
		match orientation:
			Orientation.flipped_h: return _right
			Orientation.flipped_v: return _left
			Orientation.rotated_cw: return _up
			Orientation.rotated_ccw: return _down
			_: return _left

var Right: Array[SocketType]:
	get:
		match orientation:
			Orientation.flipped_h: return _left
			Orientation.flipped_v: return _right
			Orientation.rotated_cw: return _down
			Orientation.rotated_ccw: return _up
			_: return _right
			
			
func collapse() -> Node2D:
	var instance = tiles.pick_random().instantiate()
	match orientation:
		Orientation.flipped_h: instance.scale.x = -1
		Orientation.flipped_v: instance.scale.y = -1
		Orientation.rotated_cw: instance.rotation_degrees = 90
		Orientation.rotated_ccw: instance.rotation_degrees = -90
	return instance
