@tool
extends McpTestSuite

var _interaction_count: int = 0


func suite_name() -> String:
	return "interaction"


func before_each() -> void:
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


func test_actor_state_maps_all_interaction_phases() -> void:
	var setup := _create_interaction_setup(true)
	var interaction := setup.interaction as InteractionComponent
	var actor_state := setup.actor_state as ActorStateComponent

	assert_true(interaction.interact())
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_action(),
		ActorState.Action.INTERACTING_START
	)

	interaction._update_interaction_phase(interaction.start_duration)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_action(),
		ActorState.Action.INTERACTING_PROGRESS
	)

	interaction._update_interaction_phase(interaction.progress_duration)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_action(),
		ActorState.Action.INTERACTING_END
	)

	interaction._update_interaction_phase(interaction.end_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_action(), ActorState.Action.NONE)


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
