class_name Tile extends Node2D

static var PrefabPolygons : Dictionary = {}

static var PrefabForegrounds : Dictionary[String, CompressedTexture2D] = {} :
	get():
		if PrefabForegrounds == {}:
			PrefabForegrounds = get_all_Prefabs("res://Scenes/Tile/foreground/")
		return PrefabForegrounds
		
static var PrefabBackgrounds : Dictionary[String, CompressedTexture2D] = {} :
	get():
		if PrefabBackgrounds == {}:
			PrefabBackgrounds = get_all_Prefabs("res://Scenes/Tile/background/")
		return PrefabBackgrounds

static func get_all_Prefabs(path: String) -> Dictionary[String, CompressedTexture2D]:
	assert(DirAccess.dir_exists_absolute(path), "Path does not exist: " + path)
	var results : Dictionary[String, CompressedTexture2D] = {}
	var files = DirAccess.get_files_at(path)
	
	for file in files:
		# Skip Godot import files and only process recognized image extensions
		if file.ends_with(".import"):
			continue
			
		var ext = file.get_extension().to_lower()
		if ext in ["png", "jpg", "jpeg", "svg", "webp", "tga"]:
			# Combine the base path with the filename to get the absolute path
			var full_path = path.path_join(file)
			var texture = load(full_path)
			
			if texture is CompressedTexture2D:
				results[file.get_basename()] = texture
				
	return results

var signature = ''
var body : StaticBody2D
var foreground : Sprite2D
var background : Sprite2D

func apply(chunk : Chunk, top_left_coord : Vector2i):
	
	calculate_signature(chunk, top_left_coord)
	build_background(signature)
	build_foreground(signature)
	chunk.add_child(self)
	position = (top_left_coord * Cell.SIZE) + Cell.SIZE
	
func calculate_signature(chunk : Chunk, top_left_coord : Vector2i):
	signature = ''
	signature += harvest_cell(chunk, top_left_coord)
	signature += harvest_cell(chunk, top_left_coord + Vector2i.RIGHT)
	signature += harvest_cell(chunk, top_left_coord + Vector2i.DOWN)
	signature += harvest_cell(chunk, top_left_coord + Vector2i.RIGHT + Vector2i.DOWN)
	
func harvest_cell(chunk : Chunk, coord : Vector2i) -> String: 
	chunk.grid_cells[coord].erase()
	var tag : Cell.Biomes = chunk.grid_cells[coord].Tag
	match tag:
		Cell.Biomes.sky:
			return 's'
		Cell.Biomes.underground:
			return 'c'
		Cell.Biomes.ground:
			return 'd'
	return '*'


func build_background(signature : String):
	background = Sprite2D.new()
	add_child(background)
	background.texture = PrefabBackgrounds[signature]


func build_foreground(signature : String):
	foreground = Sprite2D.new()
	add_child(foreground)
	foreground.texture = PrefabForegrounds[signature]
	var polys : Array[PackedVector2Array]
	if PrefabPolygons.has(signature):
		polys = (PrefabPolygons[signature] as Array[Polygon2D]).duplicate()
	else:	
		polys = build_polys_from_sprite(foreground)
		PrefabPolygons[signature] = polys
		
	# Create CollisionPolygon2D nodes for each generated polygon
	body = StaticBody2D.new()
	add_child(body)
	for poly in polys:
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.polygon = poly
		body.add_child(collision_polygon)
		collision_polygon.set_owner(self)
		collision_polygon.position -= Vector2(foreground.texture.get_image().get_size() / 2)


func build_polys_from_sprite(sprite : Sprite2D):

	var image := sprite.texture.get_image()
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image)

	# Convert the bitmap into an array of polygons
	return bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, image.get_size()), 0.0)


	
	
