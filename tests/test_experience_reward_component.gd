@tool
extends McpTestSuite


func suite_name() -> String:
	return "experience_reward"


func test_lethal_hit_awards_experience_once_to_source_actor() -> void:
	var source := track(Actor.new()) as Actor
	var source_components := Node2D.new()
	source_components.name = "_Components"
	source.add_child(source_components)
	var progression := ProgressionComponent.new()
	progression.config = ProgressionConfig.new()
	source_components.add_child(progression)
	source._collect_components()

	var target := track(Actor.new()) as Actor
	var target_components := Node2D.new()
	target_components.name = "_Components"
	target.add_child(target_components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = 10.0
	var hurtbox := HurtboxComponent.new()
	var reward := ExperienceRewardComponent.new()
	reward.config = ExperienceRewardConfig.new()
	reward.config.amount = 25
	for component: Component in [health, hurtbox, reward]:
		target_components.add_child(component)
	target._collect_components()
	target._collect_components()
	assert_eq(hurtbox.hit_received.get_connections().size(), 1)

	assert_eq(hurtbox.receive_hit(HitData.new(10.0, source)), 10.0)
	assert_eq(progression.get_experience(), 25)
	assert_eq(hurtbox.receive_hit(HitData.new(10.0, source)), 0.0)
	assert_eq(progression.get_experience(), 25)


func test_environmental_kill_does_not_award_experience() -> void:
	var target := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	target.add_child(components)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var hurtbox := HurtboxComponent.new()
	var reward := ExperienceRewardComponent.new()
	reward.config = ExperienceRewardConfig.new()
	for component: Component in [health, hurtbox, reward]:
		components.add_child(component)
	target._collect_components()

	assert_eq(hurtbox.receive_hit(HitData.new(100.0, null)), 100.0)
	assert_false(reward._was_awarded)
