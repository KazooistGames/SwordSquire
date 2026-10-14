class_name Tile extends Sprite2D

const PREFAB_PATH := "res://Scenes/Tile/prefab/"

static var Prefabs : Dictionary[String, CompressedTexture2D] = {} :
	get():
		if Prefabs == {}:
			Prefabs = get_all_Prefabs(PREFAB_PATH)
		return Prefabs

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


func apply(chunk : Chunk, top_left_coord : Vector2i):
	
	var signature : String = ''
	signature += get_cell_code(chunk, top_left_coord)
	signature += get_cell_code(chunk, top_left_coord + Vector2i.RIGHT)
	signature += get_cell_code(chunk, top_left_coord + Vector2i.DOWN)
	signature += get_cell_code(chunk, top_left_coord + Vector2i.RIGHT + Vector2i.DOWN)

	texture = Prefabs[signature]
	chunk.add_child(self)
	position = (top_left_coord * Cell.SIZE) + Cell.SIZE
	
func get_cell_code(chunk : Chunk, coord : Vector2i) -> String: 
	var tag : Cell.Biomes = chunk.grid_cells[coord].Tag
	match tag:
		Cell.Biomes.sky:
			return 's'
		Cell.Biomes.underground:
			return 'c'
		Cell.Biomes.ground:
			return 'd'
	return '*'
	
