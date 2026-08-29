@tool
extends McpTestSuite


func suite_name() -> String:
	return "item_use"


func test_item_heals_after_use_duration_and_reports_actor_state() -> void:
	var setup := _create_item_actor(true)
	var equipment := setup.equipment as EquipmentComponent
	var item_use := setup.item_use as ItemUseComponent
	var health := setup.health as HealthComponent
	var actor_state := setup.actor_state as ActorStateComponent
	equipment.equip(EquipmentComponent.Slot.ITEM)
	health.take_damage(50.0)

	assert_true(item_use.use_item())
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.USING_ITEM)
	assert_eq(health.get_current_health(), 50.0)

	item_use._process(item_use.config.use_duration)
	actor_state.refresh_state()
	assert_eq(health.get_current_health(), 85.0)
	assert_eq(item_use.get_remaining_charges(), 2)
	assert_eq(actor_state.get_state(), ActorState.Behavior.IDLE)


func test_switching_slot_cancels_item_without_spending_charge() -> void:
	var setup := _create_item_actor(false)
	var actor := setup.actor as Actor
	var equipment := setup.equipment as EquipmentComponent
	var item_use := setup.item_use as ItemUseComponent
	var health := setup.health as HealthComponent
	equipment.equip(EquipmentComponent.Slot.ITEM)
	health.take_damage(20.0)

	assert_true(item_use.use_item())
	equipment.equip(EquipmentComponent.Slot.MELEE)

	assert_false(item_use.is_using_item())
	assert_eq(item_use.get_remaining_charges(), 3)
	assert_eq(health.get_current_health(), 80.0)

	actor._collect_components()
	assert_eq(equipment.equipment_changed.get_connections().size(), 1)


func test_quick_health_potion_consumes_inventory_stack() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var item_use := ItemUseComponent.new()
	item_use.config = ItemUseConfig.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
	for component: Component in [
		input,
		equipment,
		health,
		item_use,
		inventory,
		quick_access,
	]:
		components.add_child(component)
	actor._collect_components()

	var potion := ItemData.new()
	potion.id = &"health_potion"
	potion.display_name = "Health Potion"
	potion.category = ItemData.Category.CONSUMABLE
	potion.stackable = true
	potion.max_stack_size = 10
	potion.usable_in_combat = true
	potion.use_effect = ItemData.UseEffect.HEAL
	potion.use_value = 35.0
	inventory.add_item(potion, 2)
	health.take_damage(50.0)
	assert_true(quick_access.activate_slot(0))
	assert_true(item_use.use_item())
	item_use._process(item_use.config.use_duration)

	assert_eq(health.get_current_health(), 85.0)
	assert_eq(inventory.get_quantity(potion.id), 1)
	assert_eq(item_use.get_remaining_charges(), 1)
	health.take_damage(15.0)
	assert_true(item_use.use_inventory_item_now(potion.id))
	assert_eq(health.get_current_health(), 100.0)
	assert_eq(inventory.get_quantity(potion.id), 0)


func _create_item_actor(include_actor_state: bool) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var equipment := EquipmentComponent.new()
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var item_use := ItemUseComponent.new()
	item_use.config = ItemUseConfig.new()
	var actor_state: ActorStateComponent

	components.add_child(input)
	components.add_child(equipment)
	components.add_child(health)
	components.add_child(item_use)

	if include_actor_state:
		actor_state = ActorStateComponent.new()
		components.add_child(actor_state)

	actor._collect_components()

	return {
		"actor": actor,
		"input": input,
		"equipment": equipment,
		"health": health,
		"item_use": item_use,
		"actor_state": actor_state,
	}
