@tool
extends McpTestSuite


func suite_name() -> String:
	return "status_effect"


func test_buff_and_debuff_overlap_refresh_and_expire() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var effects := StatusEffectComponent.new()
	var state := ActorStateComponent.new()
	components.add_child(effects)
	components.add_child(state)
	actor._collect_components()

	var buff := StatusEffect.new()
	buff.effect_id = &"strength"
	buff.duration = 2.0
	var debuff := StatusEffect.new()
	debuff.effect_id = &"poison"
	debuff.polarity = StatusEffect.Polarity.DEBUFF
	debuff.duration = 1.0

	assert_true(effects.apply_effect(buff))
	assert_true(effects.apply_effect(debuff))
	state.refresh_state()
	assert_true(state.has_status(ActorState.Status.BUFFED))
	assert_true(state.has_status(ActorState.Status.DEBUFFED))

	effects._process(0.75)
	assert_true(effects.apply_effect(debuff))
	assert_eq(effects.get_remaining(&"poison"), 1.0)
	effects._process(1.0)
	state.refresh_state()
	assert_true(state.has_status(ActorState.Status.BUFFED))
	assert_false(state.has_status(ActorState.Status.DEBUFFED))

	effects._process(0.25)
	state.refresh_state()
	assert_false(state.has_status(ActorState.Status.BUFFED))
