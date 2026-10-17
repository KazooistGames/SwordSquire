extends Node

const clear_color : Color = Color(Color.BLACK, 0.0)

const fade_out_period := 1.5
const fade_in_period := .75

var tween : Tween

signal faded_in 
signal faded_out

@onready var menu = $Menu
@onready var hud = $HUD
@onready var curtains : ColorRect = $Curtains

#TODO: disable gameplay controls object when not playing. collapse menu/session control flow into this locus here.


func _ready():
	fade_in()


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
	
