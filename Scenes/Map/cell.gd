class_name Cell extends Resource

enum Socket{
	wildcard,
	sky,
	ground,
	cave
	}
	
@export var Tag : Socket

enum Cardinal{
	UP,
	DOWN,
	LEFT,
	RIGHT
}

@export var Sockets : Dictionary[Cardinal, Socket] ={
	Cardinal.UP : Socket.wildcard,
	Cardinal.RIGHT :Socket.wildcard,
	Cardinal.DOWN : Socket.wildcard,
	Cardinal.LEFT : Socket.wildcard
}

enum Orientation{
	default,
	flipped_h,
	flipped_v,
	rotated_cw,
	rotated_ccw
}

var orientation : Orientation


func collapse():
	var tile := ColorRect.new()
	match Tag:
		Socket.sky:
			tile.color = Color.DARK_CYAN
		Socket.ground:
			tile.color = Color.SADDLE_BROWN
		Socket.cave:
			tile.color = Color.DARK_SLATE_GRAY
	return tile
	
	
func fits(other : Cell, direction : Vector2i):
	var dir = _translate_vector_to_cardinal(direction)
	
	# Debug: show the relationship being tested with enum casts
	print("Checking fit: ", Tag as Socket, " → ", other.Tag as Socket, " in direction ", dir)

	# do they fit my socket?
	var they_fit = false
	if other.Tag == Socket.wildcard: # they are a wildcard
		they_fit = true
		print("  they_fit: other is wildcard → TRUE")
	elif Sockets[dir] == Socket.wildcard: # I will take anything
		they_fit = true
		print("  they_fit: my socket is wildcard → TRUE")
	elif other.Tag == Sockets[dir]: # perfect match
		they_fit = true
		print("  they_fit: other.Tag matches my socket → TRUE")
	else:
		print("  they_fit: FAIL")
		
	var i_fit = false
	if Tag == Socket.wildcard: # I am a wildcard
		i_fit = true
		print("  i_fit: I am wildcard → TRUE")
	elif other.Sockets[_mirrored(dir)] == Socket.wildcard: # they will take anything
		i_fit = true
		print("  i_fit: other socket is wildcard → TRUE")
	elif other.Sockets[_mirrored(dir)] == Tag: # perfect match
		i_fit = true
		print("  i_fit: other socket matches my tag → TRUE")
	else:
		print("  i_fit: FAIL")
		
	var result = i_fit and they_fit
	print("  Result: ", result)
	return result
		
func _mirrored(direction : Cardinal):
	return (direction + 2) % 4
	
			
func _translate_vector_to_cardinal(direction : Vector2i) -> Cardinal:
	match direction:
		Vector2i.UP: return Cardinal.UP
		Vector2i.DOWN: return Cardinal.DOWN
		Vector2i.LEFT: return Cardinal.LEFT
		Vector2i.RIGHT: return Cardinal.RIGHT
		_: return Cardinal.UP
