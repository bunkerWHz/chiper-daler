extends Node
class_name Component

var is_enabled: bool = true
var actor: Actor = null


func initialize(parent_actor: Actor) -> void:
	actor = parent_actor
	on_initialize()


func on_initialize() -> void:
	pass


func should_disable_on_actor_death() -> bool:
	return true


func enable() -> void:
	is_enabled = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	set_physics_process(true)


func disable() -> void:
	is_enabled = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
