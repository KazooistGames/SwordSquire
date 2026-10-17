class_name UI extends CanvasLayer

'''
	used by the player interface global to handle scene transitions and other generic menu items.
'''

@onready var curtains : ColorRect = $Curtains
@onready var menu : MarginContainer = $Menu

const fade_out_period := 1.5
const fade_in_period := .75

const clear_color : Color = Color(Color.BLACK, 0.0)

signal faded_in
signal faded_out

var tween : Tween


func _ready():
	toggle_menu(true)
	fade_in()


func toggle_menu(value = null):
	if value == null:
		menu.visible = not menu.visible
	else:
		assert(value is bool)
		menu.visible = value
		
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED)
	return menu.visible


func fade_in():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(curtains, 'color', clear_color, fade_out_period)
	tween.tween_callback(func ():
		curtains.visible = false 
		faded_in.emit()
		)


func fade_out():
	curtains.visible = true
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(curtains, 'color', Color.BLACK, fade_out_period)
	tween.tween_callback(func ():
		faded_out.emit()
		)
	

func _on_quit_pressed() -> void:
	SwordSquire.quit()


func _on_fight_pressed() -> void:
	SwordSquire.load_scene("res://Scenes/Map/map.tscn")
