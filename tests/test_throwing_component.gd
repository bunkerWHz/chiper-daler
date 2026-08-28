@tool
extends McpTestSuite


func suite_name() -> String:
	return "throwing"


func test_throwing_runs_aim_action_and_recovery_states() -> void:
	var setup := _create_throwing_actor()
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var throwing := setup.throwing as ThrowingComponent
	var actor_state := setup.actor_state as ActorStateComponent
	equipment.equip(EquipmentComponent.Slot.THROWABLE)

	input._attack_just_pressed = true
	input._attack_pressed = true
	throwing._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_action(), ActorState.Action.THROWING_AIM)

	input._attack_pressed = false
	input._attack_released = true
	throwing._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_action(), ActorState.Action.THROWING_ACTION)
	assert_eq(throwing.get_remaining_charges(), 4)

	throwing._process(throwing.config.action_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_action(), ActorState.Action.THROWING_RECOVERY)

	throwing._process(throwing.config.recovery_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_action(), ActorState.Action.NONE)


func test_secondary_action_cancels_throwing_aim() -> void:
	var setup := _create_throwing_actor()
	var actor := setup.actor as Actor
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var throwing := setup.throwing as ThrowingComponent
	equipment.equip(EquipmentComponent.Slot.THROWABLE)
	input._attack_just_pressed = true
	throwing._process(0.0)
	assert_eq(throwing.get_phase(), ThrowingComponent.Phase.AIM)

	input._guard_just_pressed = true
	throwing._process(0.0)
	assert_eq(throwing.get_phase(), ThrowingComponent.Phase.NONE)
	assert_eq(throwing.get_remaining_charges(), 5)

	actor._collect_components()
	assert_eq(equipment.equipment_changed.get_connections().size(), 1)


func _create_throwing_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var throwing := ThrowingComponent.new()
	throwing.config = ThrowingConfig.new()
	var actor_state := ActorStateComponent.new()

	for component: Component in [
		input,
		equipment,
		facing,
		throwing,
		actor_state,
	]:
		components.add_child(component)

	actor._collect_components()
	return {
		"actor": actor,
		"input": input,
		"equipment": equipment,
		"facing": facing,
		"throwing": throwing,
		"actor_state": actor_state,
	}
