extends MarginContainer

'''
	used by the player interface global to handle scene transitions and other generic menu items.
'''


func toggle(value = null):
	if value == null:
		visible = not visible
	else:
		assert(value is bool)
		visible = value
		
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED)
	return visible

func _on_quit_pressed() -> void:
	SwordSquire.quit()


func _on_fight_pressed() -> void:
	SwordSquire.load_scene("res://Scenes/Map/map.tscn")
