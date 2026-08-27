@tool
extends McpTestSuite


func suite_name() -> String:
	return "rest"


func test_rest_point_heals_and_reports_resting_state() -> void:
	PlayerRespawnComponent.clear_saved_checkpoints()
	var player := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	player.add_child(components)

	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var effects := StatusEffectComponent.new()
	var respawn := PlayerRespawnComponent.new()
	respawn.config = PlayerRespawnConfig.new()
	var rest := RestComponent.new()
	rest.config = RestConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [health, effects, respawn, rest, state]:
		components.add_child(component)
	player._collect_components()
	health.take_damage(40.0)
	var buff := StatusEffect.new()
	buff.effect_id = &"blessing"
	var debuff := StatusEffect.new()
	debuff.effect_id = &"poison"
	debuff.polarity = StatusEffect.Polarity.DEBUFF
	effects.apply_effect(buff)
	effects.apply_effect(debuff)

	var point := track(RestPoint.new()) as RestPoint
	point.global_position = Vector2(120.0, 80.0)
	var point_components := Node2D.new()
	point_components.name = "_Components"
	point.add_child(point_components)
	var interactable := InteractableComponent.new()
	point_components.add_child(interactable)
	point._collect_components()
	point._ready()

	interactable.interact(player)
	state.refresh_state()
	assert_eq(health.get_current_health(), health.get_max_health())
	assert_true(effects.has_effect(&"blessing"))
	assert_false(effects.has_effect(&"poison"))
	assert_eq(
		respawn.get_checkpoint_position(),
		point.global_position + point.spawn_offset
	)
	assert_true(rest.is_resting())
	assert_true(state.has_condition(ActorState.Condition.RESTING))

	rest._process(rest.config.duration)
	state.refresh_state()
	assert_false(rest.is_resting())
	assert_false(state.has_condition(ActorState.Condition.RESTING))
