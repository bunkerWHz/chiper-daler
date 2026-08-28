extends RefCounted
class_name LocomotionConstraint

enum Block {
	NONE = 0,
	HORIZONTAL = 1 << 0,
	JUMP = 1 << 1,
	DODGE = 1 << 2,
}

const CAPABILITY_METHOD: StringName = &"get_locomotion_blocks"


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


static func get_active_blocks(providers: Array[Component]) -> int:
	var blocks: int = Block.NONE
	for provider: Component in providers:
		if is_instance_valid(provider) and provider.is_enabled:
			blocks |= int(provider.call(CAPABILITY_METHOD))
	return blocks


static func has_block(blocks: int, block: Block) -> bool:
	return (blocks & block) != 0
