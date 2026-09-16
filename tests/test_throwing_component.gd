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

	input._interact_pressed = true
	throwing._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.THROWING_AIM)

	input._interact_released = true
	throwing._process(0.0)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.THROWING_ACTION)
	assert_eq(throwing.get_remaining_charges(), 4)

	throwing._process(throwing.config.action_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.THROWING_RECOVERY)

	throwing._process(throwing.config.recovery_duration)
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.IDLE)


func test_secondary_action_cancels_throwing_aim() -> void:
	var setup := _create_throwing_actor()
	var actor := setup.actor as Actor
	var input := setup.input as InputComponent
	var equipment := setup.equipment as EquipmentComponent
	var throwing := setup.throwing as ThrowingComponent
	equipment.equip(EquipmentComponent.Slot.THROWABLE)
	input._interact_pressed = true
	throwing._process(0.0)
	assert_eq(throwing.get_phase(), ThrowingComponent.Phase.AIM)

	input._guard_just_pressed = true
	throwing._process(0.0)
	assert_eq(throwing.get_phase(), ThrowingComponent.Phase.NONE)
	assert_eq(throwing.get_remaining_charges(), 5)

	var connections := equipment.loadout_item_changed.get_connections().size()
	actor._collect_components()
	assert_eq(equipment.loadout_item_changed.get_connections().size(), connections)


func _create_throwing_actor() -> Dictionary:
	var setup := preload("res://tests/AimingTestFactory.gd").create()
	track(setup.root)
	return setup
