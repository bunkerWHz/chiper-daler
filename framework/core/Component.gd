extends Node
class_name Component

var actor: Actor

func initialize(parent_actor: Actor) -> void:
	actor = parent_actor
	on_initialize()

func on_initialize() -> void:
	pass
