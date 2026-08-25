@tool
extends McpTestSuite


func suite_name() -> String:
	return "actor_component"


func test_actor_collects_and_initializes_components() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var component := Component.new()
	component.name = "TestComponent"
	container.add_child(component)
	actor._collect_components()

	assert_eq(component.actor, actor)
	assert_true(component.is_enabled)
	assert_eq(actor.get_component(Component), component)
	assert_true(actor.has_component(Component))


func test_get_components_returns_a_snapshot() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var component := Component.new()
	container.add_child(component)
	actor._collect_components()

	var snapshot := actor.get_components()
	snapshot.clear()

	assert_eq(snapshot.size(), 0)
	assert_eq(actor.get_components().size(), 1)
	assert_true(actor.has_component(Component))


func test_component_enable_disable_controls_processing() -> void:
	var component := track(Component.new()) as Component

	component.disable()
	assert_false(component.is_enabled)
	assert_eq(component.process_mode, Node.PROCESS_MODE_DISABLED)

	component.enable()
	assert_true(component.is_enabled)
	assert_eq(component.process_mode, Node.PROCESS_MODE_INHERIT)
