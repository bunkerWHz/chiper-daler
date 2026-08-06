extends Node2D
class_name Actor

const COMPONENTS_NODE := "_Components"
var _components : Array = []

func _ready() -> void:
	_collect_components()
	
	for component in _components:
		component.initialize(self)

func _collect_components() -> void:

	var container := get_node(COMPONENTS_NODE)

	for child in container.get_children():

		if child is Component:

			var component := child as Component

			component.initialize(self)

			_components.append(component)

func get_component(type) -> Component:

	for component in _components:

		if is_instance_of(component, type):
			return component

	return null

func has_component(type) -> bool:

	return get_component(type) != null
