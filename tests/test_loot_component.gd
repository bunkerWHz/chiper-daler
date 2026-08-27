@tool
extends McpTestSuite


func suite_name() -> String:
	return "loot"


func test_health_pickup_restores_health_and_is_not_wasted_at_full_health() -> void:
	var collector := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	collector.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	components.add_child(health)
	collector._collect_components()

	var pickup := track(Pickup.new()) as Pickup
	var pickup_components := Node2D.new()
	pickup_components.name = "_Components"
	pickup.add_child(pickup_components)
	pickup_components.add_child(InteractableComponent.new())
	var data := PickupData.new()
	data.amount = 25.0
	pickup.data = data
	pickup._collect_components()
	pickup._ready()

	assert_false(pickup.try_collect(collector))
	health.take_damage(40.0)
	assert_true(pickup.try_collect(collector))
	assert_eq(health.get_current_health(), 85.0)


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
	drop.pickup_data = PickupData.new()
	drop.drop_chance = 1.0
	components.add_child(health)
	components.add_child(drop)
	enemy._collect_components()

	health.take_damage(health.get_max_health())
	assert_true(drop._has_dropped)
	assert_eq(world.get_child_count(), 2)
	var pickup := world.get_child(1) as Pickup
	assert_eq(pickup.global_position, enemy.global_position)

	drop._on_health_died()
	assert_eq(world.get_child_count(), 2)
