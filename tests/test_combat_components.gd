@tool
extends McpTestSuite

var _received_count: int = 0
var _last_hit: HitData
var _last_applied_damage: float = 0.0


func suite_name() -> String:
	return "combat"


func setup() -> void:
	_received_count = 0
	_last_hit = null
	_last_applied_damage = 0.0


func test_hurtbox_applies_hit_to_health() -> void:
	var target := _create_target(100.0)
	var source := track(Actor.new()) as Actor
	var hit := HitData.new(30.0, source)

	var applied: float = target.hurtbox.receive_hit(hit)

	assert_eq(applied, 30.0)
	assert_eq(target.health.get_current_health(), 70.0)
	assert_eq(hit.source_actor, source)


func test_hurtbox_emits_hit_received_with_applied_damage() -> void:
	var target := _create_target(20.0)
	var hit := HitData.new(50.0, null)
	target.hurtbox.hit_received.connect(_on_hit_received)

	target.hurtbox.receive_hit(hit)

	assert_eq(_received_count, 1)
	assert_eq(_last_hit, hit)
	assert_eq(_last_applied_damage, 20.0)


func test_dead_target_ignores_additional_hits() -> void:
	var target := _create_target(10.0)

	assert_eq(target.hurtbox.receive_hit(HitData.new(10.0, null)), 10.0)
	assert_eq(target.hurtbox.receive_hit(HitData.new(10.0, null)), 0.0)
	assert_eq(target.health.get_current_health(), 0.0)


func test_disabled_hurtbox_is_safe_and_ignores_hits() -> void:
	var target := _create_target(100.0)
	target.hurtbox.disable()

	var applied: float = target.hurtbox.receive_hit(HitData.new(25.0, null))

	assert_eq(applied, 0.0)
	assert_eq(target.health.get_current_health(), 100.0)


func test_invalid_hits_are_ignored() -> void:
	var target := _create_target(100.0)

	assert_eq(target.hurtbox.receive_hit(null), 0.0)
	assert_eq(target.hurtbox.receive_hit(HitData.new(0.0, null)), 0.0)
	assert_eq(target.hurtbox.receive_hit(HitData.new(-10.0, null)), 0.0)
	assert_eq(target.health.get_current_health(), 100.0)


func test_hit_reaction_changes_and_restores_visual() -> void:
	var target := _create_target(100.0)
	var visual := Node2D.new()
	visual.name = "_Visual"
	target.actor.add_child(visual)

	var reaction := HitReactionComponent.new()
	var config := HitReactionConfig.new()
	config.duration = 0.1
	config.flash_modulate = Color(1.0, 1.0, 1.0, 0.35)
	config.scale_multiplier = 1.15
	reaction.config = config
	target.actor.get_node("_Components").add_child(reaction)
	target.actor._collect_components()
	reaction._ready()

	target.hurtbox.receive_hit(HitData.new(10.0, null))

	assert_true(reaction.is_reacting())
	assert_eq(visual.modulate, config.flash_modulate)
	assert_eq(visual.scale, Vector2.ONE * config.scale_multiplier)

	reaction._process(config.duration)

	assert_false(reaction.is_reacting())
	assert_eq(visual.modulate, Color.WHITE)
	assert_eq(visual.scale, Vector2.ONE)


func test_attack_can_be_driven_without_input_or_facing() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	container.add_child(hitbox)

	var attack := AttackComponent.new()
	var config := AttackConfig.new()
	config.active_duration = 0.1
	config.cooldown = 0.3
	attack.config = config
	container.add_child(attack)

	actor._collect_components()
	hitbox._ready()
	attack._ready()

	assert_true(attack.attack())
	assert_true(attack.is_attacking())
	assert_true(area.monitoring)
	assert_false(attack.attack())

	attack._process(config.active_duration)

	assert_false(attack.is_attacking())
	assert_false(area.monitoring)
	assert_false(attack.attack())

	attack._process(config.cooldown - config.active_duration)

	assert_true(attack.attack())


func _create_target(max_health: float) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var health := HealthComponent.new()
	var config := HealthConfig.new()
	config.max_health = max_health
	health.config = config
	container.add_child(health)

	var hurtbox := HurtboxComponent.new()
	container.add_child(hurtbox)
	actor._collect_components()

	return {
		"actor": actor,
		"health": health,
		"hurtbox": hurtbox
	}


func _on_hit_received(hit: HitData, applied_damage: float) -> void:
	_received_count += 1
	_last_hit = hit
	_last_applied_damage = applied_damage
