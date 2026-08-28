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
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	var equipment := EquipmentComponent.new()
	var quick_access := QuickAccessComponent.new()
	quick_access.config = QuickAccessConfig.new()
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
		inventory,
		equipment,
		quick_access,
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
	assert_eq(inventory.add_item(potion, 2), 2)

	menu.open_inventory()
	var grid := menu.get_node(
		"CanvasLayer/Overlay/Panel/Main/Content/Inventory/Scroll/Grid"
	) as GridContainer
	assert_true(menu.is_open())
	assert_eq(grid.get_child_count(), 1)
	assert_eq((grid.get_child(0) as Button).text, "Test Potion\nx2")

	menu._select_item(potion.id)
	menu._assign_selected_to_quick_slot(3)
	assert_eq(quick_access.get_slot(3).item_id, potion.id)
	menu._drop_selected_item()
	assert_eq(inventory.get_quantity(potion.id), 1)
	assert_true(world.get_child(1) is LootBag)
	var dropped_bag := world.get_child(1) as LootBag
	assert_true(dropped_bag.try_collect(actor))
	assert_eq(inventory.get_quantity(potion.id), 2)
	menu.close_inventory()
	assert_false(menu.is_open())
