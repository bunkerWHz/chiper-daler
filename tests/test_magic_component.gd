@tool
extends McpTestSuite

var _phase_events: Array[Vector2i] = []

func suite_name() -> String:
	return "magic"

func test_magic_charge_cast_recovery_and_channeling_states() -> void:
	_phase_events.clear()
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
	magic.phase_changed.connect(_on_magic_phase_changed)
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
	assert_eq(_phase_events.size(), 5)
	assert_eq(
		_phase_events[0],
		Vector2i(MagicComponent.Phase.NONE, MagicComponent.Phase.CHARGE)
	)
	assert_eq(
		_phase_events[4],
		Vector2i(MagicComponent.Phase.NONE, MagicComponent.Phase.CHANNELING)
	)


func test_magic_cancels_on_active_loadout_and_weapon_set_changes() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var facing := FacingComponent.new()
	var magic := MagicComponent.new()
	magic.config = MagicConfig.new()
	for component: Component in [input, equipment, facing, magic]:
		components.add_child(component)
	actor._collect_components()
	equipment.equip(EquipmentComponent.Slot.MAGIC)

	input._attack_just_pressed = true
	magic._process(0.0)
	assert_eq(magic.get_phase(), MagicComponent.Phase.CHARGE)
	equipment.loadout_item_changed.emit(
		ItemData.EquipSlot.MAIN_HAND,
		0,
		equipment.get_active_weapon_set(),
		&"old_focus",
		&"new_focus"
	)
	assert_eq(magic.get_phase(), MagicComponent.Phase.NONE)

	input._attack_just_pressed = true
	magic._process(0.0)
	assert_eq(magic.get_phase(), MagicComponent.Phase.CHARGE)
	equipment.switch_weapon_set(1)
	assert_eq(magic.get_phase(), MagicComponent.Phase.NONE)

	actor._collect_components()
	assert_eq(equipment.equipment_changed.get_connections().size(), 1)
	assert_eq(equipment.loadout_item_changed.get_connections().size(), 1)
	assert_eq(equipment.weapon_set_changed.get_connections().size(), 1)


func _on_magic_phase_changed(
	previous_phase: MagicComponent.Phase,
	current_phase: MagicComponent.Phase
) -> void:
	_phase_events.append(Vector2i(previous_phase, current_phase))
