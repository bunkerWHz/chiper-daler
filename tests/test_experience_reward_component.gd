@tool
extends McpTestSuite

func suite_name() -> String:
	return "experience_reward"

func _actor() -> Actor:
	var result := Actor.new()
	var components := Node2D.new()
	components.name = "_Components"
	result.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	components.add_child(health)
	return result

func test_death_drops_amber_once_without_awarding_experience() -> void:
	var world := track(Node2D.new()) as Node2D
	var source := _actor()
	world.add_child(source)
	var progression := ProgressionComponent.new()
	progression.config = ProgressionConfig.new()
	source.get_node("_Components").add_child(progression)
	source._collect_components()
	var target := _actor()
	world.add_child(target)
	var reward := ExperienceRewardComponent.new()
	reward.config = ExperienceRewardConfig.new()
	var hurtbox := HurtboxComponent.new()
	target.get_node("_Components").add_child(hurtbox)
	target.get_node("_Components").add_child(reward)
	target._collect_components()
	target._collect_components()
	hurtbox.receive_hit(HitData.new(1000, source))
	reward._on_health_died()
	assert_eq(progression.get_experience(), 0)
	assert_eq(world.get_child_count(), 3)
	assert_true(world.get_child(2) is AmberShardPickup)
	assert_eq((world.get_child(2) as AmberShardPickup).amount, 25)

func test_environmental_death_also_drops_amber() -> void:
	var world := track(Node2D.new()) as Node2D
	var target := _actor()
	world.add_child(target)
	var reward := ExperienceRewardComponent.new()
	reward.config = ExperienceRewardConfig.new()
	target.get_node("_Components").add_child(reward)
	target._collect_components()
	(target.get_component(HealthComponent) as HealthComponent).take_damage(1000)
	assert_eq(world.get_child_count(), 2)
	assert_true(world.get_child(1) is AmberShardPickup)
