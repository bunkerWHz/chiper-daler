@tool
extends McpTestSuite


func suite_name() -> String:
	return "inventory"


func test_stackable_items_fill_existing_stacks_and_capacity() -> void:
	var inventory := _create_inventory(2)
	var potion := _create_item(&"health_potion", true, 5, 0.25)

	assert_eq(inventory.add_item(potion, 12), 10)
	assert_eq(inventory.get_quantity(potion.id), 10)
	assert_eq(inventory.get_used_slots(), 2)
	assert_true(is_equal_approx(inventory.get_total_weight(), 2.5))
	assert_eq(inventory.get_stacks()[0].quantity, 5)
	assert_eq(inventory.get_stacks()[1].quantity, 5)

	var overlay := DebugOverlayComponent.new()
	overlay.actor = inventory.actor
	var lines := PackedStringArray()
	overlay._append_inventory_info(lines)
	assert_true(lines.has("Inventory: 2 / 2  Weight: 2.50"))


func test_non_stackable_items_use_one_slot_each() -> void:
	var inventory := _create_inventory(3)
	var sword := _create_item(&"iron_sword", false, 1, 2.0)

	assert_eq(inventory.add_item(sword, 5), 3)
	assert_eq(inventory.get_quantity(sword.id), 3)
	assert_eq(inventory.get_used_slots(), 3)


func test_removal_spans_stacks_and_runtime_state_restores() -> void:
	var inventory := _create_inventory(4)
	inventory.name = "InventoryComponent"
	var potion := _create_item(&"health_potion", true, 5, 0.25)
	inventory.add_item(potion, 8)

	assert_eq(inventory.remove_item(potion.id, 6), 6)
	assert_eq(inventory.get_quantity(potion.id), 2)
	assert_false(inventory.has_item(potion.id, 3))

	var state: Variant = inventory.capture_runtime_state()
	var restored := _create_inventory(4)
	restored.restore_runtime_state(state)
	assert_eq(restored.get_quantity(potion.id), 2)
	assert_eq(restored.get_used_slots(), 1)


func _create_inventory(capacity: int) -> InventoryComponent:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var inventory := InventoryComponent.new()
	var config := InventoryConfig.new()
	config.capacity = capacity
	inventory.config = config
	components.add_child(inventory)
	actor._collect_components()
	return inventory


func _create_item(
	id: StringName,
	stackable: bool,
	max_stack_size: int,
	weight: float
) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.stackable = stackable
	item.max_stack_size = max_stack_size
	item.weight = weight
	return item
