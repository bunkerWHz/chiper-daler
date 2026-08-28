extends RefCounted
class_name PrimaryActionGate

const CAPABILITY_METHOD: StringName = &"is_primary_action_active"


static func collect_providers(
	actor: Actor,
	excluded_component: Component = null
) -> Array[Component]:
	var providers: Array[Component] = []
	for component: Component in actor.get_components():
		if (
			component != excluded_component
			and component.has_method(CAPABILITY_METHOD)
		):
			providers.append(component)
	return providers


static func has_active_action(providers: Array[Component]) -> bool:
	for provider: Component in providers:
		if (
			is_instance_valid(provider)
			and provider.is_enabled
			and bool(provider.call(CAPABILITY_METHOD))
		):
			return true
	return false
