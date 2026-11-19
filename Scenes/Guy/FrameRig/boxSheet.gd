class_name BoxSheet
extends Node

enum Type {
	hurt,
	hit,
	physics,
	interact
}
@export var type : Type = Type.hurt

@export var offset : Array[Vector2i] = [Vector2i.DOWN]
@export var radius : Array[float] = [4]
@export var height : Array[float] = [18]
