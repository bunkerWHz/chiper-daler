extends Node
class_name Component

var is_enabled: bool = false

var actor: Actor = null

func initialize(parent_actor: Actor) -> void:
	actor = parent_actor
	on_initialize()

func on_initialize() -> void:
	pass

func enable() -> void:
	is_enabled = true

func disable() -> void:
	is_enabled = false
