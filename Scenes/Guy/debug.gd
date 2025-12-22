@tool
extends Control


@onready var state_label : Label = $state
@onready var xy_label : Label = $xy
@onready var accel_label : Label = $accel
@onready var guy : Guy = $".."


func _physics_process(_delta: float) -> void:
	state_label.text = str(guy.state)
	xy_label.text = "%.0f" % guy.velocity.x
	accel_label.text = "%.0f" % guy.run_accel
