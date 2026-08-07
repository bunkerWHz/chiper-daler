extends Node2D
class_name Actor

const COMPONENTS_NODE := "_Components"
var _components : Array = []

func _enter_tree() -> void:
	_collect_components()

func _collect_components() -> void:

	var container := get_node(COMPONENTS_NODE)

	for child in container.get_children():

		if child is Component:

			var component := child as Component

			component.initialize(self)

			_components.append(component)

func get_component(component_type: Variant) -> Component:
	for component in _components:
		if is_instance_of(component, component_type):
			return component
	return null

func has_component(type) -> bool:
	return get_component(type) != null

func get_components():
	return _components
