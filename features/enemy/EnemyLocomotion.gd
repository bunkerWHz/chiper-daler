class_name EnemyLocomotion
extends RefCounted


static func find(actor: Actor) -> Component:
	if actor == null:
		return null

	for component: Component in actor.get_components():
		if (
			component.is_enabled
			and component.has_method(&"set_chase_target")
			and component.has_method(&"capture_move_intent")
			and component.has_method(&"restore_move_intent")
			and component.has_method(&"stop")
		):
			return component

	return null
