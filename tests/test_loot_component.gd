@tool
extends McpTestSuite


func suite_name() -> String:
	return "loot"


func test_pickup_adds_real_item_stack_to_inventory() -> void:
	var collector := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	collector.add_child(components)
	var inventory := InventoryComponent.new()
	inventory.config = InventoryConfig.new()
	components.add_child(inventory)
	collector._collect_components()

	var pickup := track(Pickup.new()) as Pickup
	var pickup_components := Node2D.new()
	pickup_components.name = "_Components"
	pickup.add_child(pickup_components)
	pickup_components.add_child(InteractableComponent.new())
	var item := ItemData.new()
	item.id = &"health_potion"
	item.display_name = "Health Potion"
	item.category = ItemData.Category.CONSUMABLE
	item.stackable = true
	item.max_stack_size = 10
	pickup.item = item
	pickup.quantity = 2
	pickup._collect_components()
	pickup._ready()

	assert_true(pickup.try_collect(collector))
	assert_eq(inventory.get_quantity(item.id), 2)
	assert_eq(pickup.quantity, 0)


func test_enemy_death_drops_configured_pickup_once() -> void:
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
	drop.pickup_scene = load("res://features/loot/Pickup.tscn") as PackedScene
	var drop_item := ItemData.new()
	drop_item.id = &"enemy_drop"
	drop_item.display_name = "Enemy Drop"
	drop_item.stackable = true
	drop_item.max_stack_size = 10
	drop.pickup_item = drop_item
	drop.quantity = 2
	drop.drop_chance = 1.0
	components.add_child(health)
	components.add_child(drop)
	enemy._collect_components()

	health.take_damage(health.get_max_health())
	assert_true(drop._has_dropped)
	assert_eq(world.get_child_count(), 2)
	var pickup := world.get_child(1) as Pickup
	assert_eq(pickup.global_position, enemy.global_position)
	assert_eq(pickup.item.id, drop_item.id)
	assert_eq(pickup.quantity, 2)

	drop._on_health_died()
	assert_eq(world.get_child_count(), 2)
