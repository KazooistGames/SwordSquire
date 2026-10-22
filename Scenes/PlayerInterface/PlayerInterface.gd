extends Node

const clear_color : Color = Color(Color.BLACK, 0.0)

const fade_out_period := 1.5
const fade_in_period := .75

static var guy_prefab : Resource = null:
	get():
		if guy_prefab == null:
			guy_prefab = load("res://Scenes/Guy/Archetypes/Swordsman/Swordsman.tscn")
		return guy_prefab

var tween : Tween

signal faded_in 
signal faded_out

@onready var menu : MainMenu = $Menu
@onready var harness : GameplayHarness = $Harness
@onready var curtains : ColorRect = $Curtains

func _ready():
	remove_child(harness)
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
		
		
func assume_control(target_guy : Guy):
	assert(target_guy != null)
	harness.guy = target_guy
	add_child(harness)

func release_control():
	assert(harness != null)
	remove_child(harness)
	harness.guy = null
