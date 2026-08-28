@tool
extends McpTestSuite


func suite_name() -> String:
	return "loot"


func test_loot_bag_collects_multiple_stacks() -> void:
	var collector := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	collector.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	components.add_child(inventory)
	collector._collect_components()

	var bag := track(LootBag.new()) as LootBag
	var bag_components := Node2D.new()
	bag_components.name = "_Components"
	bag.add_child(bag_components)
	bag_components.add_child(InteractableComponent.new())
	var item := ItemData.new()
	item.id = &"health_potion"
	item.display_name = "Health Potion"
	item.category = ItemData.Category.CONSUMABLE
	item.stackable = true
	item.max_stack_size = 10
	var material := ItemData.new()
	material.id = &"crafting_stone"
	material.display_name = "Crafting Stone"
	material.stackable = true
	material.max_stack_size = 10
	bag.add_item(item, 2)
	bag.add_item(material, 3)
	bag._collect_components()
	bag._ready()

	assert_true(bag.try_collect(collector))
	assert_eq(inventory.get_quantity(item.id), 2)
	assert_eq(inventory.get_quantity(material.id), 3)
	assert_true(bag.is_empty())


func test_enemy_death_drops_configured_loot_bag_once() -> void:
	var world := track(Node2D.new()) as Node2D
	var enemy := Actor.new()
	enemy.global_position = Vector2(90.0, 40.0)
	world.add_child(enemy)
	var components := Node2D.new()
	components.name = "_Components"
	enemy.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var drop := LootDropComponent.new()
	drop.loot_bag_scene = load("res://features/loot/LootBag.tscn") as PackedScene
	var drop_item := ItemData.new()
	drop_item.id = &"enemy_drop"
	drop_item.display_name = "Enemy Drop"
	drop_item.stackable = true
	drop_item.max_stack_size = 10
	var entry := LootEntry.new()
	entry.item = drop_item
	entry.minimum_quantity = 2
	entry.maximum_quantity = 2
	entry.drop_chance = 1.0
	drop.loot_entries = [entry]
	components.add_child(health)
	components.add_child(drop)
	enemy._collect_components()

	health.take_damage(health.get_max_health())
	assert_true(drop._has_dropped)
	assert_eq(world.get_child_count(), 2)
	var bag := world.get_child(1) as LootBag
	assert_eq(bag.global_position, enemy.global_position)
	assert_eq(bag.get_stacks()[0].item.id, drop_item.id)
	assert_eq(bag.get_total_quantity(), 2)

	drop._on_health_died()
	assert_eq(world.get_child_count(), 2)


func test_full_inventory_leaves_remainder_in_bag() -> void:
	var collector := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	collector.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	inventory.config.capacity = 1
	components.add_child(inventory)
	collector._collect_components()

	var item := ItemData.new()
	item.id = &"limited_stack"
	item.display_name = "Limited Stack"
	item.stackable = true
	item.max_stack_size = 2
	var bag := track(LootBag.new()) as LootBag
	bag.add_item(item, 3)

	assert_true(bag.try_collect(collector))
	assert_eq(inventory.get_quantity(item.id), 2)
	assert_eq(bag.get_total_quantity(), 1)
