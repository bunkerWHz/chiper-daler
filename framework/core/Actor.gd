extends Node2D
class_name Actor

const COMPONENTS_NODE: NodePath = ^"_Components"

var _components: Array[Component] = []


func _enter_tree() -> void:
	_collect_components()


func _collect_components() -> void:
	_components.clear()

	var container := get_node_or_null(COMPONENTS_NODE)

	if container == null:
		push_error("%s requires a _Components node" % name)
		return

	for child in container.get_children():
		if child is Component:
			_components.append(child as Component)

	for component: Component in _components:
		component.initialize(self)


func get_component(component_type: Variant) -> Component:
	for component: Component in _components:
		if is_instance_of(component, component_type):
			return component

	return null


func has_component(component_type: Variant) -> bool:
	return get_component(component_type) != null


func get_components() -> Array[Component]:
	return _components.duplicate()
