@tool
extends McpTestSuite


func suite_name() -> String:
	return "level_exit"


func test_exit_unlocks_after_all_enemies_are_dead() -> void:
	var world := track(Node2D.new()) as Node2D
	var player := Actor.new()
	var player_components := Node2D.new()
	player_components.name = "_Components"
	player.add_child(player_components)
	world.add_child(player)

	var enemy := Actor.new()
	enemy.add_to_group(&"enemies")
	var enemy_components := Node2D.new()
	enemy_components.name = "_Components"
	enemy.add_child(enemy_components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	enemy_components.add_child(health)
	world.add_child(enemy)
	enemy._collect_components()

	var exit := LevelExit.new()
	var exit_components := Node2D.new()
	exit_components.name = "_Components"
	exit.add_child(exit_components)
	exit_components.add_child(InteractableComponent.new())
	world.add_child(exit)
	exit._collect_components()
	exit._ready()

	assert_eq(exit.get_remaining_enemy_count(), 1)
	assert_false(exit.try_complete(player))
	assert_false(exit.is_completed())

	health.take_damage(health.get_max_health())
	assert_eq(exit.get_remaining_enemy_count(), 0)
	assert_true(exit.try_complete(player))
	assert_true(exit.is_completed())
