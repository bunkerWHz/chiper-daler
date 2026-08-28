@tool
extends McpTestSuite


func suite_name() -> String:
	return "inventory_menu"


func test_menu_lists_items_and_assigns_quick_slot() -> void:
	var world := track(Node2D.new()) as Node2D
	var actor := Actor.new()
	world.add_child(actor)
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var attributes := CharacterAttributesComponent.new()
	attributes.dexterity = 1
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
	var item_use := ItemUseComponent.new()
	item_use.config = ItemUseConfig.new()
	var inventory_drop := InventoryDropComponent.new()
	inventory_drop.loot_bag_scene = load(
		"res://features/loot/LootBag.tscn"
	) as PackedScene
	var menu_scene := load(
		"res://features/inventory/InventoryMenuComponent.tscn"
	) as PackedScene
	var menu := menu_scene.instantiate() as InventoryMenuComponent
	for component: Component in [
		input,
		attributes,
		health,
		inventory,
		equipment,
		quick_access,
		item_use,
		inventory_drop,
		menu,
	]:
		components.add_child(component)
	actor._collect_components()
	menu._ready()

	var potion := ItemData.new()
	potion.id = &"test_potion"
	potion.display_name = "Test Potion"
	potion.category = ItemData.Category.CONSUMABLE
	potion.stackable = true
	potion.max_stack_size = 10
	potion.usable_in_combat = true
	potion.use_effect = ItemData.UseEffect.HEAL
	potion.use_value = 35.0
	assert_eq(inventory.add_item(potion, 3), 3)
	health.take_damage(50.0)

	menu.open_inventory()
	var grid := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Content/Inventory/Scroll/Grid"
	) as GridContainer
	assert_true(menu.is_open())
	assert_eq(grid.get_child_count(), inventory.get_capacity())
	assert_eq((grid.get_child(0) as Button).text, "Test Potion\nx3")
	var summary := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Content/Inventory/Summary"
	) as Label
	assert_true(summary.text.contains("Slots 1 / 40"))

	menu._select_item(potion.id)
	menu._use_selected_item()
	assert_eq(health.get_current_health(), 85.0)
	assert_eq(inventory.get_quantity(potion.id), 2)
	menu._assign_selected_to_quick_slot(3)
	assert_eq(quick_access.get_slot(3).item_id, potion.id)
	menu._assign_selected_to_quick_slot(3)
	assert_eq(quick_access.get_slot(3).kind, QuickAccessSlot.Kind.EMPTY)
	menu._request_drop_selected_item()
	assert_eq(menu._drop_quantity.max_value, 2.0)
	menu._drop_quantity.value = 2
	menu._confirm_drop_selected_item()
	assert_eq(inventory.get_quantity(potion.id), 0)
	assert_true(world.get_child(1) is LootBag)
	var dropped_bag := world.get_child(1) as LootBag
	assert_true(dropped_bag.try_collect(actor))
	assert_eq(inventory.get_quantity(potion.id), 2)
	var potion_payload := menu._inventory_item_payload(potion)
	var quick_drop_target := track(
		InventoryDragButton.new()
	) as InventoryDragButton
	quick_drop_target.drop_target = InventoryDragButton.TARGET_QUICK_SLOT
	assert_true(quick_drop_target._can_drop_data(Vector2.ZERO, potion_payload))
	menu._on_quick_slot_data_dropped(potion_payload, 3)
	assert_eq(quick_access.get_slot(3).item_id, potion.id)
	menu._on_inventory_data_dropped({
		"kind": InventoryDragButton.KIND_QUICK_SLOT,
		"slot_index": 3,
	})
	assert_eq(quick_access.get_slot(3).kind, QuickAccessSlot.Kind.EMPTY)

	var sword := ItemData.new()
	sword.id = &"test_sword"
	sword.display_name = "Test Sword"
	sword.category = ItemData.Category.WEAPON
	sword.equip_slot = ItemData.EquipSlot.MAIN_HAND
	sword.stats = ItemStats.new()
	sword.stats.damage = 5.0
	sword.sell_price = 25
	inventory.add_item(sword)
	equipment.equip_inventory_item(sword.id, sword.equip_slot)
	var sword_payload := menu._inventory_item_payload(sword)
	var equipment_drop_target := track(
		InventoryDragButton.new()
	) as InventoryDragButton
	equipment_drop_target.drop_target = InventoryDragButton.TARGET_EQUIPMENT
	equipment_drop_target.target_equip_slot = ItemData.EquipSlot.MAIN_HAND
	assert_true(equipment_drop_target._can_drop_data(Vector2.ZERO, sword_payload))
	equipment_drop_target.target_equip_slot = ItemData.EquipSlot.RING
	assert_false(equipment_drop_target._can_drop_data(Vector2.ZERO, sword_payload))
	menu._on_inventory_data_dropped({
		"kind": InventoryDragButton.KIND_EQUIPPED_ITEM,
		"equip_slot": ItemData.EquipSlot.MAIN_HAND,
		"slot_index": 0,
		"weapon_set": 0,
	})
	assert_false(equipment.is_item_equipped(sword.id))
	menu._on_equipment_data_dropped(
		sword_payload, ItemData.EquipSlot.MAIN_HAND, 0, 1
	)
	assert_eq(
		equipment.get_equipped_item_id(ItemData.EquipSlot.MAIN_HAND, 0, 1),
		sword.id
	)
	equipment.unequip_item(ItemData.EquipSlot.MAIN_HAND, 0, 1)
	equipment.equip_inventory_item(sword.id, sword.equip_slot, 0, 0)
	var crossbow := ItemData.new()
	crossbow.id = &"test_crossbow"
	crossbow.display_name = "Test Crossbow"
	crossbow.category = ItemData.Category.WEAPON
	crossbow.equip_slot = ItemData.EquipSlot.MAIN_HAND
	crossbow.stats = ItemStats.new()
	crossbow.stats.damage = 12.0
	crossbow.stats.dexterity_requirement = 3
	crossbow.sell_price = 100
	inventory.add_item(crossbow)
	menu._on_category_selected(ItemData.Category.WEAPON + 1)
	assert_eq(grid.get_child_count(), 2)
	menu._on_sort_selected(InventoryMenuComponent.SortMode.VALUE)
	assert_true((grid.get_child(0) as Button).text.begins_with("Test Crossbow"))
	menu._on_category_selected(0)
	assert_eq(grid.get_child_count(), inventory.get_capacity())
	var equipment_slots := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Content/Equipment/EquipmentScroll/EquipmentSlots"
	) as GridContainer
	assert_eq(equipment_slots.get_child_count(), 14)
	menu._activate_weapon_set(1)
	assert_eq(equipment.get_active_weapon_set(), 1)
	menu._activate_weapon_set(0)
	assert_eq(equipment.get_active_weapon_set(), 0)
	menu._select_item(crossbow.id)
	var details := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Details"
	) as Label
	var equip_button := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Actions/Equip"
	) as Button
	assert_true(details.text.contains("Requirements not met: DEX 3"))
	assert_true(details.text.contains("Compared with Test Sword"))
	assert_true(details.text.contains("Damage +7.0"))
	assert_true(equip_button.disabled)
	menu._select_item(sword.id)
	menu._equip_selected_item()
	assert_false(equipment.is_item_equipped(sword.id))
	menu.close_inventory()
	assert_false(menu.is_open())
