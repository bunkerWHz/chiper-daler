extends Node
class_name Component

var is_enabled : bool = false

var actor: Node = null

func initialize(parent_actor: Node) -> void:
	actor = parent_actor
	on_initialize()

func on_initialize() -> void:
	pass
func enable():
	is_enabled = true
	
func disable():
	is_enabled = false
