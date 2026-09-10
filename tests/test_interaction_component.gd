@tool
extends McpTestSuite

var _interaction_count: int = 0


class BehaviorStub:
	extends Component

	var active: bool = false


	func is_exclusive_behavior_active() -> bool:
		return active


func suite_name() -> String:
	return "interaction"


func setup() -> void:
	_interaction_count = 0


func test_interaction_runs_start_progress_and_end_phases() -> void:
	var setup := _create_interaction_setup(false)
	var interaction := setup.interaction as InteractionComponent
	var interactable := setup.interactable as InteractableComponent
	interactable.interacted.connect(_on_interacted)

	assert_true(interaction.interact())
	assert_eq(_interaction_count, 1)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.START)
	assert_false(interaction.interact())

	interaction._update_interaction_phase(interaction.start_duration)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.PROGRESS)

	interaction._update_interaction_phase(interaction.progress_duration)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.END)

	interaction._update_interaction_phase(interaction.end_duration)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.NONE)
	assert_false(interaction.is_interacting())

	interaction.cooldown_timer = 0.0
	interaction.current_target = interactable
	assert_true(interaction.interact())
	interaction.disable()
	assert_false(interaction.is_interacting())
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.NONE)


func test_scaled_loot_can_be_collected_from_ground_beside_either_edge() -> void:
	for bag_scale: float in [0.5, 1.0, 3.0]:
		var setup := _create_interaction_setup(false)
		var collector := setup.actor as Actor
		var interaction := setup.interaction as InteractionComponent
		var inventory := InventoryComponent.new()
		inventory.config = InventoryConfig.new()
		collector.get_node("_Components").add_child(inventory)
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child(collector)
		collector.process_mode = Node.PROCESS_MODE_DISABLED
		var bag := track(preload("res://features/loot/LootBag.tscn").instantiate()) as LootBag
		bag.scale = Vector2.ONE * bag_scale
		bag.position = Vector2(400, 200)
		var item := ItemData.new()
		item.id = &"edge_loot"
		item.display_name = "Edge loot"
		bag.add_item(item)
		tree.root.add_child(bag)
		bag.process_mode = Node.PROCESS_MODE_DISABLED
		var target := bag.get_component(InteractableComponent) as InteractableComponent
		var shape := bag.get_node("_Components/CharacterBodyComponent/CharacterBody2D/CollisionShape2D") as CollisionShape2D
		var bounds := shape.shape.get_rect()
		for direction: float in [-1.0, 1.0]:
			var side_x := bounds.position.x if direction < 0.0 else bounds.end.x
			var ground_edge := shape.to_global(Vector2(side_x, bounds.end.y))
			collector.global_position = ground_edge + Vector2(direction * 24.0, -10.0)
			interaction._update_target()
			assert_eq(interaction.get_target(), target)
			assert_true(is_equal_approx(collector.global_position.distance_to(target.get_closest_interaction_point(collector.global_position)), 24.0))
			collector.global_position = ground_edge + Vector2(direction * 49.0, -10.0)
			interaction._update_target()
			assert_eq(interaction.get_target(), null)
		# The nearest point follows both the body offset and the root transform.
		collector.global_position = shape.to_global(bounds.end) + Vector2(24, -10)
		interaction._update_target()
		assert_true(interaction.interact())
		assert_eq(inventory.get_quantity(item.id), 1)
		assert_true(bag.is_empty())
		interaction._update_target()
		assert_eq(interaction.get_target(), null)
		bag.free()
		collector.free()


func test_interactable_without_shape_keeps_its_actor_position() -> void:
	var setup := _create_interaction_setup(false)
	var target := setup.target as Actor
	target.position = Vector2(30, 50)
	var interactable := setup.interactable as InteractableComponent
	assert_eq(interactable.get_closest_interaction_point(Vector2(100, 100)), target.global_position)


func test_actor_state_maps_all_interaction_phases() -> void:
	var setup := _create_interaction_setup(true)
	var interaction := setup.interaction as InteractionComponent
	var actor_state := setup.actor_state as ActorStateComponent

	assert_true(interaction.interact())
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_state(),
		ActorState.Behavior.INTERACTING_START
	)

	interaction._update_interaction_phase(interaction.start_duration)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_state(),
		ActorState.Behavior.INTERACTING_PROGRESS
	)

	interaction._update_interaction_phase(interaction.progress_duration)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_state(),
		ActorState.Behavior.INTERACTING_END
	)

	interaction._update_interaction_phase(interaction.end_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.IDLE)


func test_interaction_waits_for_an_active_exclusive_behavior() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var action := BehaviorStub.new()
	var interaction := InteractionComponent.new()
	components.add_child(input)
	components.add_child(action)
	components.add_child(interaction)
	actor._collect_components()

	var target := track(Actor.new()) as Actor
	var target_components := Node2D.new()
	target_components.name = "_Components"
	target.add_child(target_components)
	var interactable := InteractableComponent.new()
	target_components.add_child(interactable)
	target._collect_components()
	interactable.interacted.connect(_on_interacted)
	interaction.current_target = interactable

	action.active = true
	assert_false(interaction.interact())
	assert_eq(_interaction_count, 0)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.NONE)

	action.active = false
	assert_true(interaction.interact())
	assert_eq(_interaction_count, 1)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.START)


func test_context_action_is_left_for_hotbar_without_a_world_target() -> void:
	var setup := _create_interaction_setup(false)
	var interaction := setup.interaction as InteractionComponent
	var interactable := setup.interactable as InteractableComponent
	var input := interaction.input_component
	interactable.interacted.connect(_on_interacted)

	interaction.current_target = null
	input._interact_pressed = true
	interaction._process_context_action()
	assert_true(input.consume_interact_pressed())
	assert_eq(_interaction_count, 0)

	interaction.current_target = interactable
	input._interact_pressed = true
	interaction._process_context_action()
	assert_false(input.consume_interact_pressed())
	assert_eq(_interaction_count, 1)


func test_all_actor_actions_publish_the_exclusive_behavior_capability() -> void:
	var providers: Array[Component] = [
		track(AttackComponent.new()) as AttackComponent,
		track(GuardComponent.new()) as GuardComponent,
		track(ItemUseComponent.new()) as ItemUseComponent,
		track(ThrowingComponent.new()) as ThrowingComponent,
		track(RangedWeaponComponent.new()) as RangedWeaponComponent,
		track(MagicComponent.new()) as MagicComponent,
		track(DodgeComponent.new()) as DodgeComponent,
		track(ClimbingComponent.new()) as ClimbingComponent,
		track(RestComponent.new()) as RestComponent,
	]

	for provider: Component in providers:
		assert_true(provider.has_method(&"is_exclusive_behavior_active"))


func test_interaction_hands_off_to_a_behavior_started_by_the_target() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var behavior := BehaviorStub.new()
	var interaction := InteractionComponent.new()
	components.add_child(input)
	components.add_child(behavior)
	components.add_child(interaction)
	actor._collect_components()

	var target := track(Actor.new()) as Actor
	var target_components := Node2D.new()
	target_components.name = "_Components"
	target.add_child(target_components)
	var interactable := InteractableComponent.new()
	target_components.add_child(interactable)
	target._collect_components()
	interactable.interacted.connect(_activate_behavior.bind(behavior))
	interaction.current_target = interactable

	assert_true(interaction.interact())
	assert_true(behavior.active)
	assert_eq(interaction.get_phase(), InteractionComponent.Phase.NONE)


func _create_interaction_setup(include_actor_state: bool) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var interaction := InteractionComponent.new()
	components.add_child(input)
	components.add_child(interaction)

	var actor_state: ActorStateComponent

	if include_actor_state:
		actor_state = ActorStateComponent.new()
		components.add_child(actor_state)

	actor._collect_components()

	var target := track(Actor.new()) as Actor
	var target_components := Node2D.new()
	target_components.name = "_Components"
	target.add_child(target_components)
	var interactable := InteractableComponent.new()
	target_components.add_child(interactable)
	target._collect_components()
	interaction.current_target = interactable

	return {
		"actor": actor,
		"interaction": interaction,
		"actor_state": actor_state,
		"target": target,
		"interactable": interactable,
	}


func _on_interacted() -> void:
	_interaction_count += 1


func _activate_behavior(behavior: BehaviorStub) -> void:
	behavior.active = true
