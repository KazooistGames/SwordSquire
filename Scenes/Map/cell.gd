class_name Cell extends Resource

enum SocketType{
	wildcard,
	sky,
	ground,
	cave
	}
	
@export var MyType : SocketType

@export var _up: SocketType
@export var _down: SocketType
@export var _left: SocketType
@export var _right: SocketType

enum Orientation{
	default,
	flipped_h,
	flipped_v,
	rotated_cw,
	rotated_ccw
}

var orientation : Orientation

var Up: SocketType:
	get:
		match orientation:
			Orientation.flipped_h: return _up
			Orientation.flipped_v: return _down
			Orientation.rotated_cw: return _left
			Orientation.rotated_ccw: return _right
			_: return _up

var Down: SocketType:
	get:
		match orientation:
			Orientation.flipped_h: return _down
			Orientation.flipped_v: return _up
			Orientation.rotated_cw: return _right
			Orientation.rotated_ccw: return _left
			_: return _down

var Left: SocketType:
	get:
		match orientation:
			Orientation.flipped_h: return _right
			Orientation.flipped_v: return _left
			Orientation.rotated_cw: return _up
			Orientation.rotated_ccw: return _down
			_: return _left

var Right: SocketType:
	get:
		match orientation:
			Orientation.flipped_h: return _left
			Orientation.flipped_v: return _right
			Orientation.rotated_cw: return _down
			Orientation.rotated_ccw: return _up
			_: return _right
			
			
func collapse():
	var tile := ColorRect.new()
	match MyType:
		SocketType.sky:
			tile.color = Color.DARK_CYAN
		SocketType.ground:
			tile.color = Color.SADDLE_BROWN
		SocketType.cave:
			tile.color = Color.DARK_SLATE_GRAY
	return tile
	
			
