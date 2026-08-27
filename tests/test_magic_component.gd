@tool
extends McpTestSuite

func suite_name() -> String:
	return "magic"

func test_magic_charge_cast_recovery_and_channeling_states() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var magic := MagicComponent.new()
	magic.config = MagicConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [input, equipment, facing, magic, state]:
		components.add_child(component)
	actor._collect_components()
	equipment.equip(EquipmentComponent.Slot.MAGIC)
	input._attack_just_pressed = true
	input._attack_pressed = true
	magic._process(0.0)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.MAGIC_CHARGE)
	input._attack_pressed = false
	input._attack_released = true
	magic._process(0.0)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.MAGIC_CAST)
	assert_eq(magic.get_mana(), 80.0)
	magic._process(magic.config.cast_duration)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.MAGIC_RECOVERY)
	magic._process(magic.config.recovery_duration)
	input._guard_just_pressed = true
	input._guard_pressed = true
	magic._process(0.0)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.MAGIC_CHANNELING)
