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
	helmet.usable_in_combat = false
	inventory.add_item(bomb, 3)
	inventory.add_item(helmet)

	assert_eq(quick_access.get_slot(0).kind, QuickAccessSlot.Kind.WEAPON_SET)
	assert_eq(quick_access.get_slot(1).weapon_set, 1)
	assert_eq(quick_access.get_slot(2).item_id, &"health_potion")
	assert_false(quick_access.assign_item(2, bomb.id))
	assert_false(quick_access.assign_item(3, helmet.id))
	assert_true(quick_access.activate_slot(4))
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.CROSSBOW)
	assert_true(quick_access.assign_item(3, bomb.id))
	assert_false(quick_access.assign_item(4, bomb.id))

	input._equipment_slot_request = 3
	quick_access._process(0.0)
	equipment._process(0.0)
	assert_eq(quick_access.get_active_slot(), 3)
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.THROWABLE)
	assert_eq(quick_access.get_active_item_quantity(), 3)
	var overlay := DebugOverlayComponent.new()
	overlay.actor = setup.actor as Actor
	var lines := PackedStringArray()
	overlay._append_quick_access_info(lines)
	assert_true(lines.has("Quick Slot: 4  fire_bomb x3"))

	input._equipment_slot_request = 1
	quick_access._process(0.0)
	assert_eq(equipment.get_active_weapon_set(), 1)
	assert_eq(equipment.get_current_slot(), EquipmentComponent.Slot.MELEE)


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
