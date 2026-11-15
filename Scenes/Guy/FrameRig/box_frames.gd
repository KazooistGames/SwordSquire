class_name BoxFrames
extends Node

enum Type {
	hurt,
	hit,
	physics,
	interact
}
@export var type : Type = Type.hurt

@export var offset : Array[Vector2i]
@export var radius : Array[float]
@export var height : Array[float]
