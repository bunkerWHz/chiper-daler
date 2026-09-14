@tool
extends McpTestSuite


func suite_name() -> String:
	return "dot_effects"


func _target(hp: float = 100.0) -> Actor:
	var target := track(Actor.new()) as Actor
	var container := Node.new()
	container.name = "_Components"
	target.add_child(container)
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	health.config.max_health = hp
	container.add_child(health)
	container.add_child(StatusEffectComponent.new())
	container.add_child(HurtboxComponent.new())
	target._collect_components()
	return target


func _dot(id: StringName = &"burning", duration: float = 3.0) -> StatusEffect:
	var generator := track(DotEffectGenerator.new()) as DotEffectGenerator
	generator.effect_id = id
	generator.duration = duration
	generator.damage_per_tick = 5.0
	return generator.build_effect()


func test_ticks_include_expiration_boundary_and_catch_up() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	assert_true(effects.apply_effect(_dot()))
	effects._process(0.5)
	assert_eq(health.get_current_health(), 100.0)
	effects._process(10.0)
	assert_eq(health.get_current_health(), 85.0)
	assert_false(effects.has_debuff())


func test_refresh_keeps_tick_schedule_and_names_run_independently() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	effects.apply_effect(_dot())
	effects._process(0.75)
	effects.apply_effect(_dot())
	effects.apply_effect(_dot(&"my_custom_poison"))
	effects._process(0.25)
	assert_eq(health.get_current_health(), 95.0)
	effects._process(0.75)
	assert_eq(health.get_current_health(), 90.0)
	assert_eq(effects.clear_debuffs(), 2)
	effects._process(10.0)
	assert_eq(health.get_current_health(), 90.0)


func test_partial_interval_does_not_deal_extra_damage() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	effects.apply_effect(_dot(&"bleeding", 1.5))
	effects._process(2.0)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)


func test_shared_resources_have_independent_runtime_state() -> void:
	var first := _target()
	var second := _target()
	var a := first.get_component(StatusEffectComponent) as StatusEffectComponent
	var b := second.get_component(StatusEffectComponent) as StatusEffectComponent
	var dot := _dot()
	a.apply_effect(dot)
	b.apply_effect(dot)
	dot.damage_per_tick = 1000.0
	a._process(1.0)
	assert_eq((first.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)
	assert_eq((second.get_component(HealthComponent) as HealthComponent).get_current_health(), 100.0)
	assert_eq(b.get_remaining(&"burning"), 3.0)


func test_death_and_disable_cancel_all_pending_ticks() -> void:
	var target := _target(5.0)
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	effects.apply_effect(_dot())
	effects.apply_effect(_dot(&"poison"))
	effects._process(10.0)
	assert_false(effects.has_debuff())
	assert_false(effects.apply_effect(_dot()))
	var other := _target()
	var other_effects := other.get_component(StatusEffectComponent) as StatusEffectComponent
	other_effects.apply_effect(_dot())
	other_effects.disable()
	other_effects._process(10.0)
	assert_false(other_effects.has_debuff())
	assert_eq((other.get_component(HealthComponent) as HealthComponent).get_current_health(), 100.0)


func test_successful_hit_applies_dot_and_invalid_hit_does_not() -> void:
	var target := _target()
	var hurtbox := target.get_component(HurtboxComponent) as HurtboxComponent
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var hit := HitData.new(0.0, null)
	hit.status_effects = [_dot()]
	assert_eq(hurtbox.receive_hit(hit), 0.0)
	assert_false(effects.has_debuff())
	hit.damage = 10.0
	assert_eq(hurtbox.receive_hit(hit), 10.0)
	assert_true(effects.has_effect(&"burning"))
	effects._process(1.0)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 85.0)


func test_invalid_parameters_and_missing_health_are_rejected() -> void:
	var effects := track(StatusEffectComponent.new()) as StatusEffectComponent
	assert_false(effects.apply_effect(_dot()))
	var dot := _dot()
	dot.tick_interval = 0.0
	assert_false(dot.is_valid())
	dot.tick_interval = 0.00000001
	assert_false(dot.is_valid())
	dot.tick_interval = 1.0
	dot.duration = INF
	assert_false(dot.is_valid())


func test_tick_handler_can_clear_effects() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	effects.effect_ticked.connect(func(_effect: StatusEffect, _damage: float) -> void: effects.clear_debuffs())
	effects.apply_effect(_dot())
	effects.apply_effect(_dot(&"poison"))
	effects._process(10.0)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)
	assert_false(effects.has_debuff())


func test_stronger_dot_replaces_damage_duration_and_restarts_tick() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	effects.apply_effect(_dot(&"poison", 10.0))
	effects._process(0.75)
	var strong := _dot(&"poison", 2.0)
	strong.damage_per_tick = 10.0
	assert_true(effects.apply_effect(strong))
	assert_eq(effects.get_remaining(&"poison"), 2.0)
	effects._process(0.25)
	assert_eq(health.get_current_health(), 100.0)
	effects._process(0.75)
	assert_eq(health.get_current_health(), 90.0)
	effects._process(1.0)
	assert_eq(health.get_current_health(), 80.0)
	assert_false(effects.has_effect(&"poison"))


func test_weaker_dot_cannot_replace_extend_or_change_next_tick() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var health := target.get_component(HealthComponent) as HealthComponent
	var applied_count := [0]
	effects.effect_applied.connect(func(_effect: StatusEffect) -> void: applied_count[0] += 1)
	var strong := _dot(&"poison", 2.0)
	strong.damage_per_tick = 10.0
	effects.apply_effect(strong)
	effects._process(0.75)
	var weak := _dot(&"poison", 100.0)
	weak.damage_per_tick = 20.0
	weak.tick_interval = 10.0
	assert_false(effects.apply_effect(weak))
	assert_eq(effects.get_remaining(&"poison"), 1.25)
	assert_eq(applied_count[0], 1)
	effects._process(0.25)
	assert_eq(health.get_current_health(), 90.0)
	assert_false(effects.apply_effect(weak))
	effects._process(1.0)
	assert_eq(health.get_current_health(), 80.0)
	assert_false(effects.has_effect(&"poison"))
	# Rejected weak applications are not queued; a new application can now succeed.
	assert_true(effects.apply_effect(weak))
	effects._process(10.0)
	assert_eq(health.get_current_health(), 60.0)


func test_higher_dps_with_smaller_ticks_replaces_slower_dot() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var slow := _dot(&"poison", 20.0)
	slow.damage_per_tick = 6.0
	slow.tick_interval = 10.0
	effects.apply_effect(slow)
	effects._process(0.75)
	assert_true(effects.apply_effect(_dot(&"poison", 2.0)))
	assert_eq(effects.get_remaining(&"poison"), 2.0)
	effects._process(0.25)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 100.0)
	effects._process(0.75)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)


func test_equal_dps_with_different_intervals_retains_existing_ticks_in_both_orders() -> void:
	for slow_first: bool in [true, false]:
		var target := _target()
		var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
		var health := target.get_component(HealthComponent) as HealthComponent
		var slow := _dot(&"poison", 4.0)
		slow.damage_per_tick = 10.0
		slow.tick_interval = 2.0
		var fast := _dot(&"poison", 4.0)
		var initial := slow if slow_first else fast
		var incoming := fast if slow_first else slow
		effects.apply_effect(initial)
		effects._process(0.75)
		incoming.duration = 6.0
		var announced: Array[StatusEffect] = []
		effects.effect_applied.connect(func(value: StatusEffect) -> void: announced.append(value))
		assert_true(effects.apply_effect(incoming))
		assert_eq(effects.get_remaining(&"poison"), 6.0)
		assert_eq(announced[0].damage_per_tick, initial.damage_per_tick)
		assert_eq(announced[0].tick_interval, initial.tick_interval)
		assert_eq(announced[0].duration, 6.0)
		assert_eq(initial.duration, 4.0)
		effects._process(0.25)
		assert_eq(health.get_current_health(), 100.0 if slow_first else 95.0)
		effects._process(1.0)
		assert_eq(health.get_current_health(), 90.0)


func test_equal_strength_refreshes_duration_without_postponing_tick() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	effects.apply_effect(_dot(&"poison", 2.0))
	effects._process(0.75)
	assert_true(effects.apply_effect(_dot(&"poison", 4.0)))
	assert_eq(effects.get_remaining(&"poison"), 4.0)
	effects._process(0.25)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)


func test_strength_rule_is_per_id_and_uses_base_damage_before_resistance() -> void:
	var target := _target()
	var effects := target.get_component(StatusEffectComponent) as StatusEffectComponent
	var strong := _dot(&"poison")
	strong.damage_per_tick = 10.0
	effects.dot_resistances.set_percent(&"poison", 100.0)
	effects.apply_effect(strong)
	assert_false(effects.apply_effect(_dot(&"poison")))
	assert_true(effects.apply_effect(_dot(&"burning")))
	effects._process(1.0)
	assert_eq((target.get_component(HealthComponent) as HealthComponent).get_current_health(), 95.0)
	assert_true(effects.has_effect(&"poison"))
	assert_true(effects.has_effect(&"burning"))
