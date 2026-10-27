extends Node

const clear_color : Color = Color(Color.BLACK, 0.0)

const fade_out_period := 1.5
const fade_in_period := .75

var tween : Tween

@onready var menu : MainMenu = $Menu
@onready var camera : Camera2D = $Camera
@onready var curtains : ColorRect = $Curtains

signal faded_in 
signal faded_out


func _ready():
	menu.toggle(true)
	fade_in()
	
	
# always processed
func _input(event: InputEvent) -> void:
	if event.is_action_pressed('Escape'):
		menu.toggle()


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
		
		
