@tool
extends McpTestSuite


func suite_name() -> String:
	return "quick_access"


func test_fixed_and_configurable_slots_switch_combat_context() -> void:
	var setup := _create_quick_access_actor()
	var input := setup.input as InputComponent
	var inventory := setup.inventory as InventoryComponent
	var equipment := setup.equipment as EquipmentComponent
	var quick_access := setup.quick_access as QuickAccessComponent

	var health_potion := _create_quick_item(
		&"health_potion",
		ItemData.Category.CONSUMABLE,
		ItemData.CombatMode.NONE
	)
	var bomb := _create_quick_item(
		&"fire_bomb",
		ItemData.Category.THROWABLE,
		ItemData.CombatMode.THROWABLE
	)
	var helmet := _create_quick_item(
		&"helmet",
		ItemData.Category.ARMOR,
		ItemData.CombatMode.NONE
	)
	var knife := _create_quick_item(
		&"throwing_knife",
		ItemData.Category.THROWABLE,
		ItemData.CombatMode.THROWABLE
	)
	helmet.usable_in_combat = false
	inventory.add_item(health_potion, 2)
	inventory.add_item(bomb, 3)
	inventory.add_item(knife, 2)
	inventory.add_item(helmet)

	assert_eq(quick_access.get_slot(0).kind, QuickAccessSlot.Kind.ITEM)
	assert_eq(quick_access.get_slot(0).item_id, &"health_potion")
	assert_eq(quick_access.get_slot(1).kind, QuickAccessSlot.Kind.EMPTY)
	assert_true(quick_access.is_slot_available(0))
	assert_false(quick_access.is_slot_available(1))
	assert_false(quick_access.assign_item(0, bomb.id))
	assert_false(quick_access.assign_item(1, helmet.id))
	assert_false(quick_access.assign_item(1, health_potion.id))
	assert_false(quick_access.activate_slot(1))
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.MELEE)
	assert_eq(InputComponent.QUICK_SLOT_ACTIONS[0], &"quick_slot_1")
	assert_eq(InputComponent.QUICK_SLOT_ACTIONS[5], &"quick_slot_6")
	assert_eq(InputComponent.QUICK_SLOT_PREVIOUS_ACTION, &"quick_slot_previous")
	assert_eq(InputComponent.QUICK_SLOT_NEXT_ACTION, &"quick_slot_next")
	assert_eq(InputComponent.WEAPON_SET_SWAP_ACTION, &"weapon_set_swap")
	assert_true(InputMap.has_action(InputComponent.QUICK_SLOT_PREVIOUS_ACTION))
	assert_true(InputMap.has_action(InputComponent.QUICK_SLOT_NEXT_ACTION))
	assert_true(InputMap.has_action(InputComponent.WEAPON_SET_SWAP_ACTION))
	assert_true(quick_access.assign_item(1, bomb.id))
	assert_false(quick_access.assign_item(2, bomb.id))

	input._quick_slot_request = 1
	quick_access._process(0.0)
	equipment._process(0.0)
	assert_eq(quick_access.get_active_slot(), 1)
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.THROWABLE)
	assert_eq(quick_access.get_active_item_quantity(), 3)
	var overlay := DebugOverlayComponent.new()
	overlay.actor = setup.actor as Actor
	var lines := PackedStringArray()
	overlay._append_quick_access_info(lines)
	assert_true(lines.has("Quick Slot: 2  fire_bomb x3"))
	assert_true(quick_access.assign_item(2, knife.id))
	assert_true(quick_access.swap_slots(1, 2))
	assert_eq(quick_access.get_slot(1).item_id, knife.id)
	assert_eq(quick_access.get_slot(2).item_id, bomb.id)
	assert_eq(quick_access.get_active_slot(), 2)
	assert_false(quick_access.swap_slots(0, 2))
	input._quick_slot_cycle_request = -1
	quick_access._process(0.0)
	assert_eq(quick_access.get_active_slot(), 1)
	input._quick_slot_cycle_request = 1
	quick_access._process(0.0)
	assert_eq(quick_access.get_active_slot(), 2)
	input._quick_slot_cycle_request = 1
	quick_access._process(0.0)
	assert_eq(quick_access.get_active_slot(), 0)
	input._quick_slot_cycle_request = -1
	quick_access._process(0.0)
	assert_eq(quick_access.get_active_slot(), 2)
	assert_true(quick_access.activate_slot(2))
	inventory.remove_item(bomb.id, 3)
	assert_eq(quick_access.get_active_slot(), 0)

	(setup.actor as Actor)._collect_components()
	assert_eq(inventory.inventory_changed.get_connections().size(), 2)


func _create_quick_access_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
	for component: Component in [input, equipment, inventory, quick_access]:
		components.add_child(component)
	actor._collect_components()
	return {
		"actor": actor,
		"input": input,
		"equipment": equipment,
		"inventory": inventory,
		"quick_access": quick_access,
	}


func _create_quick_item(
	id: StringName,
	category: ItemData.Category,
	combat_mode: ItemData.CombatMode
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.category = category
	item.combat_mode = combat_mode
	item.stackable = true
	item.max_stack_size = 10
	item.usable_in_combat = true
	return item
