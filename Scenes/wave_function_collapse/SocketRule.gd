class_name SocketRule extends RefCounted

enum SocketType {
	wildcard = 0,
	air = 1,
	grass = 2,
	dirt = 3,
	cave = 4
}
@export var Type : SocketType
@export var _up: Array[SocketType] = []
@export var _down: Array[SocketType] = []
@export var _left: Array[SocketType] = []
@export var _right: Array[SocketType] = []

var UpSockets: Array[SocketType]:
	get:
		if VerticallySymmeyrical:
			return _up + _down
		return _up
	set(value):
		_up = value

var DownSockets: Array[SocketType]:
	get:
		if VerticallySymmeyrical:
			return _up + _down
		return _down
	set(value):
		_down = value

var LeftSockets: Array[SocketType]:
	get:
		if HorizontallySymmetrical:
			return _left + _right
		return _left
	set(value):
		_left = value

var RightSockets: Array[SocketType]:
	get:
		if HorizontallySymmetrical:
			return _left + _right
		return _right
	set(value):
		_right = value
		
@export var HorizontallySymmetrical : bool = false
@export var VerticallySymmeyrical : bool = false
