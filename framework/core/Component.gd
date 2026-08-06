extends Node
class_name Component

var actor: Node = null

func initialize(parent_actor: Node) -> void:
	actor = parent_actor
	on_initialize()

func on_initialize() -> void:
	pass
