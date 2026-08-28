@tool
extends McpTestSuite

var _received_count: int = 0
var _last_hit: HitData
var _last_applied_damage: float = 0.0


class GroundStateBodyComponent:
	extends CharacterBodyComponent

	var grounded: bool = true


	func is_on_floor() -> bool:
		return grounded


	func move_and_slide() -> void:
		pass


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
	var visual_root := Node2D.new()
	visual_root.name = "_Visual"
	target.actor.add_child(visual_root)
	var body_visual := Node2D.new()
	body_visual.name = "Body"
	visual_root.add_child(body_visual)
	var health_bar := Node2D.new()
	health_bar.name = "HealthBar"
	visual_root.add_child(health_bar)

	var reaction := HitReactionComponent.new()
	var config := HitReactionConfig.new()
	config.duration = 0.1
	config.flash_modulate = Color(1.0, 1.0, 1.0, 0.35)
	config.scale_multiplier = 1.15
	reaction.config = config
	reaction.visual_path = ^"_Visual/Body"
	var actor_state := ActorStateComponent.new()
	target.actor.get_node("_Components").add_child(reaction)
	target.actor.get_node("_Components").add_child(actor_state)
	target.actor._collect_components()
	reaction._ready()

	target.hurtbox.receive_hit(HitData.new(10.0, null))

	assert_true(reaction.is_reacting())
	assert_eq(body_visual.modulate, config.flash_modulate)
	assert_eq(body_visual.scale, Vector2.ONE * config.scale_multiplier)
	assert_eq(health_bar.modulate, Color.WHITE)
	assert_eq(health_bar.scale, Vector2.ONE)
	actor_state.refresh_state()
	assert_true(actor_state.has_condition(ActorState.Condition.HIT))

	reaction._process(config.duration)
	actor_state.refresh_state()

	assert_false(reaction.is_reacting())
	assert_false(actor_state.has_condition(ActorState.Condition.HIT))
	assert_eq(body_visual.modulate, Color.WHITE)
	assert_eq(body_visual.scale, Vector2.ONE)
	assert_eq(health_bar.modulate, Color.WHITE)
	assert_eq(health_bar.scale, Vector2.ONE)


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

	attack.set_horizontal_direction(-1.0)
	assert_eq(hitbox.get_horizontal_direction(), -1.0)
	attack.set_horizontal_direction(1.0)
	assert_eq(hitbox.get_horizontal_direction(), 1.0)

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


func test_attack_interrupts_guard_and_guard_resumes_after_attack() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)

	var attack := AttackComponent.new()
	var attack_config := AttackConfig.new()
	attack_config.active_duration = 0.1
	attack_config.cooldown = 0.1
	attack.config = attack_config

	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [input, facing, hitbox, attack, guard]:
		container.add_child(component)

	actor._collect_components()
	hitbox._ready()
	attack._ready()

	assert_true(guard.start_guard())
	assert_true(attack.attack())
	assert_false(guard.is_guarding())
	assert_false(guard.start_guard())

	attack._process(attack_config.active_duration)

	assert_true(guard.start_guard())


func test_guard_is_grounded_and_locks_locomotion() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var input := InputComponent.new()
	var body_component := GroundStateBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	var facing := FacingComponent.new()
	var movement := MovementComponent.new()
	movement.config = MovementConfig.new()
	var dodge := DodgeComponent.new()
	dodge.config = DodgeConfig.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [
		input,
		body_component,
		facing,
		movement,
		dodge,
		guard,
	]:
		container.add_child(component)

	actor._collect_components()
	body_component.set_velocity(Vector2(200.0, 0.0))
	input._jump_pressed = true

	assert_true(dodge.try_start_dodge())
	assert_true(dodge.is_dodging())
	assert_true(guard.start_guard())
	dodge._physics_process(0.0)
	assert_false(dodge.is_dodging())
	dodge._cooldown_timer = 0.0
	assert_false(dodge.can_dodge())
	movement._physics_process(0.0)
	assert_eq(body_component.get_velocity(), Vector2.ZERO)
	assert_eq(movement._jump_buffer_timer, 0.0)
	assert_false(input._jump_pressed)

	input._move_axis = -1.0
	facing._physics_process(0.0)
	assert_eq(facing.get_direction(), FacingComponent.Direction.LEFT)

	input._guard_pressed = true
	body_component.grounded = false
	guard._process(0.0)
	assert_false(guard.is_defending())
	assert_false(guard.start_guard())
	assert_false(guard.start_parry())


func test_held_attack_becomes_heavy_and_restores_hitbox_damage() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var input := InputComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	hitbox.damage = 10.0
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()

	container.add_child(input)
	container.add_child(hitbox)
	container.add_child(attack)
	actor._collect_components()
	hitbox._ready()
	attack._ready()

	input._attack_just_pressed = true
	input._attack_pressed = true
	attack._process(0.0)
	assert_true(attack.is_charging_heavy_attack())

	attack._process(attack.config.heavy_charge_time)
	assert_true(attack.is_heavy_attacking())
	assert_eq(hitbox.damage, 20.0)
	assert_true(area.monitoring)

	attack._process(attack.config.heavy_active_duration)
	assert_false(attack.is_attacking())
	assert_eq(hitbox.damage, 10.0)
	assert_false(area.monitoring)


func test_released_attack_remains_light_attack() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var input := InputComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()

	container.add_child(input)
	container.add_child(hitbox)
	container.add_child(attack)
	actor._collect_components()
	hitbox._ready()
	attack._ready()

	input._attack_just_pressed = true
	input._attack_pressed = true
	attack._process(0.0)
	input._attack_pressed = false
	input._attack_released = true
	attack._process(0.1)

	assert_true(attack.is_attacking())
	assert_false(attack.is_heavy_attacking())
	assert_eq(hitbox.damage, 10.0)


func test_damage_number_view_rises_and_fades() -> void:
	var view := track(DamageNumberView.new()) as DamageNumberView
	var config := DamageNumberConfig.new()
	config.duration = 1.0
	config.rise_distance = 20.0
	var start_position := Vector2(10.0, 30.0)
	view.setup(25.0, start_position, config)

	assert_eq(view.get_damage(), 25.0)
	assert_eq(view.position, start_position)

	view._process(0.5)

	assert_eq(view.position, start_position + Vector2(0.0, -10.0))
	assert_true(absf(view.modulate.a - 0.5) < 0.001)


func test_invulnerability_blocks_repeated_damage() -> void:
	var target := _create_target(100.0)
	var invulnerability := InvulnerabilityComponent.new()
	var config := InvulnerabilityConfig.new()
	config.duration = 0.5
	invulnerability.config = config
	target.actor.get_node("_Components").add_child(invulnerability)
	target.actor._collect_components()

	assert_eq(target.hurtbox.receive_hit(HitData.new(25.0, null)), 25.0)
	assert_true(invulnerability.is_invulnerable())
	assert_eq(target.hurtbox.receive_hit(HitData.new(25.0, null)), 0.0)
	assert_eq(target.health.get_current_health(), 75.0)

	invulnerability._process(config.duration)

	assert_false(invulnerability.is_invulnerable())
	assert_eq(target.hurtbox.receive_hit(HitData.new(25.0, null)), 25.0)
	assert_eq(target.health.get_current_health(), 50.0)


func test_invulnerability_blink_restores_visual() -> void:
	var target := _create_target(100.0)
	var visual := Node2D.new()
	visual.name = "_Visual"
	target.actor.add_child(visual)

	var invulnerability := InvulnerabilityComponent.new()
	var config := InvulnerabilityConfig.new()
	config.duration = 0.2
	config.blink_interval = 0.05
	config.blink_alpha = 0.35
	invulnerability.config = config
	target.actor.get_node("_Components").add_child(invulnerability)
	target.actor._collect_components()
	invulnerability._ready()

	invulnerability.activate()

	assert_true(absf(visual.modulate.a - 0.35) < 0.001)

	invulnerability._process(config.blink_interval)

	assert_eq(visual.modulate, Color.WHITE)

	invulnerability._process(config.duration)

	assert_false(invulnerability.is_invulnerable())
	assert_eq(visual.modulate, Color.WHITE)


func test_knockback_applies_hit_velocity() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	body.owner = body_component
	container.add_child(body_component)

	var knockback := KnockbackComponent.new()
	var config := KnockbackConfig.new()
	config.duration = 0.2
	knockback.config = config
	container.add_child(knockback)
	actor._collect_components()

	var velocity := Vector2(180.0, -100.0)
	var hit := HitData.new(10.0, null, velocity)

	assert_true(knockback.apply_hit(hit))
	assert_true(knockback.is_knocked_back())
	assert_eq(body.velocity, velocity)
	assert_eq(hit.knockback_velocity, velocity)


func test_hit_stop_changes_and_restores_time_scale() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var hitbox := HitboxComponent.new()
	container.add_child(hitbox)

	var hit_stop := HitStopComponent.new()
	var config := HitStopConfig.new()
	config.duration = 0.05
	config.time_scale = 0.1
	config.on_hit_received = false
	hit_stop.config = config
	container.add_child(hit_stop)
	actor._collect_components()

	var previous_time_scale := Engine.time_scale

	assert_true(hit_stop.trigger())
	assert_true(hit_stop.is_active())
	assert_eq(Engine.time_scale, config.time_scale)

	hit_stop.stop()

	assert_false(hit_stop.is_active())
	assert_eq(Engine.time_scale, previous_time_scale)


func test_hit_stop_triggers_when_owner_is_hit() -> void:
	var target := _create_target(100.0)
	var hit_stop := HitStopComponent.new()
	var config := HitStopConfig.new()
	config.on_hit_landed = false
	config.on_hit_received = true
	config.time_scale = 0.1
	hit_stop.config = config
	target.actor.get_node("_Components").add_child(hit_stop)
	target.actor._collect_components()

	var previous_time_scale := Engine.time_scale
	target.hurtbox.receive_hit(HitData.new(10.0, null))

	assert_true(hit_stop.is_active())
	assert_eq(Engine.time_scale, config.time_scale)

	hit_stop.stop()
	assert_eq(Engine.time_scale, previous_time_scale)


func test_camera_shake_restores_camera_offset() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var hitbox := HitboxComponent.new()
	container.add_child(hitbox)

	var camera_component := CameraComponent.new()
	var camera_config := CameraConfig.new()
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera_component.config = camera_config
	camera_component.add_child(camera)
	container.add_child(camera_component)

	var camera_shake := CameraShakeComponent.new()
	var shake_config := CameraShakeConfig.new()
	shake_config.duration = 0.1
	shake_config.strength = 3.0
	shake_config.on_hit_received = false
	camera_shake.config = shake_config
	container.add_child(camera_shake)
	actor._collect_components()

	var original_offset := Vector2(4.0, 2.0)
	camera.offset = original_offset

	assert_true(camera_shake.trigger())
	assert_true(camera_shake.is_shaking())

	camera_shake._process(shake_config.duration)

	assert_false(camera_shake.is_shaking())
	assert_eq(camera.offset, original_offset)


func test_camera_shake_triggers_when_owner_is_hit() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	container.add_child(health)

	var hurtbox := HurtboxComponent.new()
	container.add_child(hurtbox)

	var camera_component := CameraComponent.new()
	camera_component.config = CameraConfig.new()
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera_component.add_child(camera)
	container.add_child(camera_component)

	var camera_shake := CameraShakeComponent.new()
	var shake_config := CameraShakeConfig.new()
	shake_config.on_hit_landed = false
	shake_config.on_hit_received = true
	camera_shake.config = shake_config
	container.add_child(camera_shake)
	actor._collect_components()

	hurtbox.receive_hit(HitData.new(10.0, null))

	assert_true(camera_shake.is_shaking())
	camera_shake.stop()


func test_enemy_attack_restores_movement_after_knockback() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	body.owner = body_component
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	var movement_config := EnemyMovementConfig.new()
	movement_config.initial_direction = -1.0
	movement.config = movement_config
	container.add_child(movement)

	var hitbox := HitboxComponent.new()
	container.add_child(hitbox)

	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	container.add_child(attack)

	var enemy_attack := EnemyAttackComponent.new()
	enemy_attack.config = EnemyAttackConfig.new()
	container.add_child(enemy_attack)
	actor._collect_components()

	enemy_attack._stop_movement()
	assert_eq(movement.get_move_direction(), 0.0)

	movement.disable()
	enemy_attack._resume_movement()
	assert_eq(movement.get_move_direction(), 0.0)

	movement.enable()
	enemy_attack._resume_movement()
	assert_eq(movement.get_move_direction(), -1.0)


func test_hit_stun_suspends_and_restores_enemy_movement() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	movement.config = EnemyMovementConfig.new()
	container.add_child(movement)

	var hit_stun := HitStunComponent.new()
	var hit_stun_config := HitStunConfig.new()
	hit_stun_config.duration = 0.2
	hit_stun.config = hit_stun_config
	container.add_child(hit_stun)
	var actor_state := ActorStateComponent.new()
	container.add_child(actor_state)
	actor._collect_components()

	assert_true(movement.is_enabled)
	assert_true(hit_stun.apply_hit(HitData.new(10.0, null)))
	assert_true(hit_stun.is_stunned())
	assert_false(movement.is_enabled)
	actor_state.refresh_state()
	assert_true(actor_state.has_condition(ActorState.Condition.STUNNED))

	hit_stun._process(hit_stun_config.duration)
	actor_state.refresh_state()

	assert_false(hit_stun.is_stunned())
	assert_true(movement.is_enabled)
	assert_false(actor_state.has_condition(ActorState.Condition.STUNNED))

	assert_true(hit_stun.apply_hit(HitData.new(10.0, null)))
	assert_false(movement.is_enabled)
	hit_stun.disable()
	assert_false(hit_stun.is_stunned())
	assert_true(movement.is_enabled)


func test_knockback_and_hit_stun_share_movement_ownership() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	movement.config = EnemyMovementConfig.new()
	container.add_child(movement)

	var knockback := KnockbackComponent.new()
	var knockback_config := KnockbackConfig.new()
	knockback_config.duration = 0.1
	knockback.config = knockback_config
	container.add_child(knockback)

	var hit_stun := HitStunComponent.new()
	var hit_stun_config := HitStunConfig.new()
	hit_stun_config.duration = 0.2
	hit_stun.config = hit_stun_config
	container.add_child(hit_stun)
	actor._collect_components()

	var hit := HitData.new(10.0, null, Vector2(100.0, -50.0))
	assert_true(knockback.apply_hit(hit))
	assert_true(hit_stun.apply_hit(hit))
	assert_false(movement.is_enabled)

	knockback._finish_knockback()

	assert_false(movement.is_enabled)
	assert_true(hit_stun.is_stunned())

	hit_stun._process(hit_stun_config.duration)

	assert_false(hit_stun.is_stunned())
	assert_true(movement.is_enabled)

	knockback_config.duration = 0.2
	hit_stun_config.duration = 0.1
	assert_true(knockback.apply_hit(hit))
	assert_true(hit_stun.apply_hit(hit))

	hit_stun._process(hit_stun_config.duration)

	assert_false(hit_stun.is_stunned())
	assert_false(movement.is_enabled)

	knockback._finish_knockback()

	assert_true(movement.is_enabled)


func test_disabling_knockback_transfers_active_movement_suspension() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	container.add_child(body_component)
	var movement := EnemyMovementComponent.new()
	movement.config = EnemyMovementConfig.new()
	container.add_child(movement)
	var knockback := KnockbackComponent.new()
	knockback.config = KnockbackConfig.new()
	container.add_child(knockback)
	var hit_stun := HitStunComponent.new()
	hit_stun.config = HitStunConfig.new()
	container.add_child(hit_stun)
	actor._collect_components()

	var hit := HitData.new(10.0, null, Vector2(100.0, -50.0))
	assert_true(knockback.apply_hit(hit))
	assert_true(hit_stun.apply_hit(hit))
	assert_false(movement.is_enabled)
	knockback.disable()
	assert_false(movement.is_enabled)
	hit_stun._process(hit_stun.config.duration)
	assert_true(movement.is_enabled)


func test_strong_hit_knocks_actor_down() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	movement.config = EnemyMovementConfig.new()
	container.add_child(movement)

	var knockback := KnockbackComponent.new()
	var knockback_config := KnockbackConfig.new()
	knockback_config.duration = 0.2
	knockback.config = knockback_config
	container.add_child(knockback)

	var hit_stun := HitStunComponent.new()
	var config := HitStunConfig.new()
	config.knockdown_velocity_threshold = 300.0
	config.knockdown_duration = 0.7
	hit_stun.config = config
	container.add_child(hit_stun)

	var actor_state := ActorStateComponent.new()
	container.add_child(actor_state)
	actor._collect_components()

	var hit := HitData.new(20.0, null, Vector2(350.0, -150.0))
	assert_true(knockback.apply_hit(hit))
	assert_true(hit_stun.apply_hit(hit))
	actor_state.refresh_state()
	assert_true(hit_stun.is_knocked_down())
	assert_false(hit_stun.is_stunned())
	assert_false(movement.is_enabled)
	assert_true(actor_state.has_condition(ActorState.Condition.KNOCKED_DOWN))

	knockback._finish_knockback()
	assert_false(movement.is_enabled)

	hit_stun._process(config.knockdown_duration)
	actor_state.refresh_state()
	assert_false(hit_stun.is_knocked_down())
	assert_true(movement.is_enabled)
	assert_false(actor_state.has_condition(ActorState.Condition.KNOCKED_DOWN))


func test_backstab_reports_critical_attack_state() -> void:
	var attacker := track(Actor.new()) as Actor
	attacker.global_position.x = 0.0
	var attacker_components := Node2D.new()
	attacker_components.name = "_Components"
	attacker.add_child(attacker_components)

	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [hitbox, attack, state]:
		attacker_components.add_child(component)
	attacker._collect_components()

	var target := track(Actor.new()) as Actor
	target.global_position.x = 40.0
	var target_components := Node2D.new()
	target_components.name = "_Components"
	target.add_child(target_components)
	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	target_components.add_child(body_component)
	var movement := EnemyMovementComponent.new()
	movement.config = EnemyMovementConfig.new()
	movement.config.initial_direction = 1.0
	target_components.add_child(movement)
	target._collect_components()

	assert_true(hitbox._is_backstab(target, 1.0))
	assert_false(hitbox._is_backstab(target, -1.0))
	attack._on_critical_hit_landed(null, 20.0)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.CRITICAL_ATTACK)

	attack._process(attack.config.critical_state_duration)
	state.refresh_state()
	assert_eq(state.get_action(), ActorState.Action.NONE)


func test_enemy_attack_telegraphs_before_attacking() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)
	var visual := Node2D.new()
	visual.name = "_Visual"
	actor.add_child(visual)
	var telegraph_visual := Node2D.new()
	telegraph_visual.name = "Body"
	visual.add_child(telegraph_visual)
	var health_bar := Node2D.new()
	health_bar.name = "HealthBar"
	visual.add_child(health_bar)

	var hitbox := HitboxComponent.new()
	var hitbox_area := Area2D.new()
	hitbox_area.name = "Area2D"
	hitbox.add_child(hitbox_area)
	container.add_child(hitbox)

	var attack := AttackComponent.new()
	var attack_config := AttackConfig.new()
	attack_config.active_duration = 0.1
	attack_config.cooldown = 0.3
	attack.config = attack_config
	container.add_child(attack)

	var enemy_attack := EnemyAttackComponent.new()
	var enemy_config := EnemyAttackConfig.new()
	enemy_config.windup_duration = 0.2
	enemy_attack.config = enemy_config
	enemy_attack.visual_path = ^"_Visual/Body"
	var detection_area := Area2D.new()
	detection_area.name = "DetectionArea2D"
	var detection_shape := CollisionShape2D.new()
	detection_shape.name = "CollisionShape2D"
	detection_shape.shape = RectangleShape2D.new()
	detection_area.add_child(detection_shape)
	enemy_attack.add_child(detection_area)
	container.add_child(enemy_attack)

	var hit_stun := HitStunComponent.new()
	var hit_stun_config := HitStunConfig.new()
	hit_stun_config.duration = 0.2
	hit_stun.config = hit_stun_config
	container.add_child(hit_stun)

	actor._collect_components()
	hitbox._ready()
	attack._ready()
	enemy_attack._ready()

	var target := _create_target(100.0)
	target.actor.global_position.x = 10.0
	var target_area := Area2D.new()
	target.hurtbox.add_child(target_area)
	enemy_attack._on_area_entered(target_area)

	enemy_attack._process(0.1)
	assert_false(attack.is_attacking())
	assert_true(enemy_attack.is_winding_up())
	assert_eq(telegraph_visual.modulate, enemy_config.telegraph_modulate)
	assert_eq(health_bar.modulate, Color.WHITE)

	enemy_attack._on_area_exited(target_area)
	assert_false(enemy_attack.has_target())
	assert_false(enemy_attack.is_winding_up())
	assert_false(attack.is_attacking())
	assert_eq(telegraph_visual.modulate, Color.WHITE)
	assert_eq(health_bar.modulate, Color.WHITE)

	enemy_attack._on_area_entered(target_area)
	enemy_attack._process(0.1)
	assert_true(enemy_attack.is_winding_up())
	assert_false(attack.is_attacking())

	assert_true(hit_stun.apply_hit(HitData.new(10.0, null)))
	assert_false(enemy_attack.is_enabled)
	assert_false(enemy_attack.is_winding_up())
	assert_false(attack.is_attacking())
	assert_eq(telegraph_visual.modulate, Color.WHITE)
	assert_eq(enemy_attack.process_mode, Node.PROCESS_MODE_INHERIT)

	hit_stun._process(hit_stun_config.duration)
	assert_true(enemy_attack.is_enabled)
	assert_true(attack.is_enabled)
	enemy_attack._on_area_entered(target_area)

	enemy_attack._process(0.1)
	assert_false(attack.is_attacking())
	assert_eq(telegraph_visual.modulate, enemy_config.telegraph_modulate)
	assert_eq(health_bar.modulate, Color.WHITE)

	enemy_attack._process(0.1)
	assert_true(attack.is_attacking())
	assert_eq(telegraph_visual.modulate, Color.WHITE)

	attack._process(attack_config.active_duration)
	enemy_attack._process(0.1)
	assert_eq(enemy_attack._windup_target, null)
	assert_eq(telegraph_visual.modulate, Color.WHITE)


func test_hit_stun_interrupts_and_restores_attack() -> void:
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
	attack.config = AttackConfig.new()
	container.add_child(attack)

	var hit_stun := HitStunComponent.new()
	var stun_config := HitStunConfig.new()
	stun_config.duration = 0.2
	hit_stun.config = stun_config
	container.add_child(hit_stun)
	actor._collect_components()
	hitbox._ready()
	attack._ready()

	assert_true(attack.attack())
	assert_true(area.monitoring)
	assert_true(hit_stun.apply_hit(HitData.new(10.0, null)))
	assert_true(hit_stun.is_stunned())
	assert_false(attack.is_enabled)
	assert_false(area.monitoring)

	hit_stun._process(stun_config.duration)

	assert_false(hit_stun.is_stunned())
	assert_true(attack.is_enabled)


func test_hitbox_ignores_allies_and_damages_hostiles() -> void:
	var attacker := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	attacker.add_child(container)

	var attacker_faction := CombatFactionComponent.new()
	attacker_faction.faction = CombatFactionComponent.Faction.ENEMY
	container.add_child(attacker_faction)

	var hitbox := HitboxComponent.new()
	var hitbox_area := Area2D.new()
	hitbox_area.name = "Area2D"
	hitbox.add_child(hitbox_area)
	container.add_child(hitbox)
	attacker._collect_components()
	hitbox._ready()

	var target := _create_target(100.0)
	var target_faction := CombatFactionComponent.new()
	target_faction.faction = CombatFactionComponent.Faction.ENEMY
	target.actor.get_node("_Components").add_child(target_faction)
	var hurtbox_area := Area2D.new()
	target.hurtbox.add_child(hurtbox_area)
	target.actor._collect_components()

	assert_eq(
		attacker.get_component(CombatFactionComponent),
		attacker_faction
	)
	assert_eq(
		target.actor.get_component(CombatFactionComponent),
		target_faction
	)
	assert_false(attacker_faction.is_hostile_to(target_faction.faction))
	assert_false(hitbox._can_hit(target.hurtbox))

	hitbox._on_area_entered(hurtbox_area)
	assert_eq(target.health.get_current_health(), 100.0)

	target_faction.faction = CombatFactionComponent.Faction.PLAYER
	hitbox._on_area_entered(hurtbox_area)
	assert_eq(target.health.get_current_health(), 90.0)


func test_enemy_chase_moves_toward_hostile_target() -> void:
	var enemy := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	enemy.add_child(container)

	var faction := CombatFactionComponent.new()
	faction.faction = CombatFactionComponent.Faction.ENEMY
	container.add_child(faction)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	body.owner = body_component
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	var movement_config := EnemyMovementConfig.new()
	movement_config.initial_direction = -1.0
	movement.config = movement_config
	container.add_child(movement)

	var chase := EnemyChaseComponent.new()
	var chase_config := EnemyChaseConfig.new()
	chase_config.avoid_unsafe_ground = false
	chase.config = chase_config
	container.add_child(chase)
	enemy._collect_components()

	var target := _create_target(100.0)
	var target_faction := CombatFactionComponent.new()
	target_faction.faction = CombatFactionComponent.Faction.PLAYER
	target.actor.get_node("_Components").add_child(target_faction)
	var hurtbox_area := Area2D.new()
	target.hurtbox.add_child(hurtbox_area)
	target.actor.position.x = 100.0
	target.actor._collect_components()

	chase._on_area_entered(hurtbox_area)
	chase._process(0.0)

	assert_true(chase.is_chasing())
	assert_eq(movement.get_move_direction(), 1.0)

	target_faction.faction = CombatFactionComponent.Faction.ENEMY
	chase._process(0.0)

	assert_false(chase.is_chasing())
	assert_eq(movement.get_move_direction(), -1.0)


func test_enemy_jump_uses_configured_trajectory_reach() -> void:
	var actor := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	actor.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	var movement_config := EnemyMovementConfig.new()
	movement_config.move_speed = 100.0
	movement_config.gravity = 1200.0
	movement.config = movement_config
	container.add_child(movement)

	var ground_sensor := EnemyGroundSensorComponent.new()
	ground_sensor.config = EnemyGroundSensorConfig.new()
	container.add_child(ground_sensor)

	var chase := EnemyChaseComponent.new()
	chase.config = EnemyChaseConfig.new()
	container.add_child(chase)

	var jump := EnemyJumpComponent.new()
	var jump_config := EnemyJumpConfig.new()
	jump_config.jump_velocity = 450.0
	jump_config.landing_tolerance = 0.0
	jump.config = jump_config
	container.add_child(jump)
	actor._collect_components()

	assert_true(jump.is_enabled)
	assert_true(jump.can_reach_offset(Vector2(70.0, 0.0)))
	assert_false(jump.can_reach_offset(Vector2(80.0, 0.0)))
	assert_true(jump.can_reach_offset(Vector2(80.0, 50.0)))
	assert_false(jump.can_reach_offset(Vector2(10.0, -100.0)))
	assert_true(
		absf(jump.get_required_horizontal_speed(Vector2(60.0, 0.0)) - 80.0)
		< 0.001
	)


func test_enemy_jump_requires_a_landing_surface_by_default() -> void:
	var config := EnemyJumpConfig.new()

	assert_true(config.require_landing_surface)
	assert_true(config.landing_probe_up >= 0.0)
	assert_true(config.landing_probe_depth >= 64.0)


func test_enemy_jump_ignores_an_airborne_target() -> void:
	var jump := EnemyJumpComponent.new()
	jump.config = EnemyJumpConfig.new()

	assert_false(jump.is_jumping())
	assert_false(
		jump.should_attempt_jump(Vector2(40.0, -30.0), false, false)
	)
	assert_false(
		jump.should_attempt_jump(Vector2(40.0, 0.0), false, true)
	)
	assert_true(
		jump.should_attempt_jump(Vector2(40.0, -30.0), true, false)
	)
	jump.free()


func test_enemy_movement_direction_can_be_committed_for_a_jump() -> void:
	var movement := EnemyMovementComponent.new()

	assert_true(movement.set_move_direction(1.0))
	movement.lock_move_direction()
	assert_true(movement.is_move_direction_locked())
	assert_false(movement.set_move_direction(-1.0))
	assert_eq(movement.get_move_direction(), 1.0)

	movement.unlock_move_direction()
	assert_true(movement.set_move_direction(-1.0))
	assert_eq(movement.get_move_direction(), -1.0)
	movement.free()


func test_enemy_platform_sandbox_has_reachable_and_unreachable_steps() -> void:
	var packed_scene := load(
		"res://tests/EnemyPlatformSandbox.tscn"
	) as PackedScene
	assert_true(packed_scene != null)

	var sandbox := track(packed_scene.instantiate())
	assert_true(sandbox.get_node_or_null("Player") != null)
	assert_true(sandbox.get_node_or_null("Enemy") != null)
	assert_true(
		sandbox.get_node_or_null("Platforms/MiddlePlatform") != null
	)
	assert_true(
		sandbox.get_node_or_null("Platforms/UnreachablePlatform") != null
	)
	assert_true(
		sandbox.get_node_or_null(
			"Platforms/MiddlePlatform/EnemyReachMarker"
		) != null
	)


func test_enemy_patrol_reverses_movement_direction() -> void:
	var enemy := track(Actor.new()) as Actor
	var container := Node2D.new()
	container.name = "_Components"
	enemy.add_child(container)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	body.owner = body_component
	container.add_child(body_component)

	var movement := EnemyMovementComponent.new()
	var movement_config := EnemyMovementConfig.new()
	movement_config.initial_direction = -1.0
	movement.config = movement_config
	container.add_child(movement)

	var ground_sensor := EnemyGroundSensorComponent.new()
	ground_sensor.config = EnemyGroundSensorConfig.new()
	container.add_child(ground_sensor)

	var patrol := EnemyPatrolComponent.new()
	patrol.config = EnemyPatrolConfig.new()
	container.add_child(patrol)
	enemy._collect_components()

	assert_true(patrol.reverse_direction())
	assert_eq(movement.get_move_direction(), 1.0)


func test_guard_reduces_only_frontal_damage() -> void:
	var target := _create_target(100.0)
	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var guard := GuardComponent.new()
	var guard_config := GuardConfig.new()
	guard_config.damage_multiplier = 0.25
	guard.config = guard_config
	var hit_stun := HitStunComponent.new()
	var hit_stun_config := HitStunConfig.new()
	hit_stun_config.duration = 0.2
	hit_stun.config = hit_stun_config
	target.actor.get_node("_Components").add_child(input)
	target.actor.get_node("_Components").add_child(facing)
	target.actor.get_node("_Components").add_child(guard)
	target.actor.get_node("_Components").add_child(hit_stun)
	target.actor._collect_components()

	var source := track(Actor.new()) as Actor
	source.global_position.x = 100.0
	var front_hit := HitData.new(40.0, source)

	assert_true(guard.start_guard())
	assert_false(guard.allows_hit_reactions(front_hit))
	assert_eq(
		target.hurtbox.receive_hit(front_hit),
		10.0
	)
	assert_true(guard.is_guarding())
	assert_false(hit_stun.is_stunned())

	source.global_position.x = -100.0
	assert_true(guard.allows_hit_reactions(HitData.new(40.0, source)))
	assert_eq(
		target.hurtbox.receive_hit(HitData.new(40.0, source)),
		40.0
	)
	assert_true(hit_stun.is_stunned())
	assert_false(guard.is_enabled)
	assert_false(guard.is_guarding())

	hit_stun._process(hit_stun_config.duration)
	assert_true(guard.is_enabled)
	assert_eq(target.health.get_current_health(), 50.0)


func test_parry_negates_frontal_hit_and_uses_cooldown() -> void:
	var target := _create_target(100.0)
	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [input, facing, guard]:
		target.actor.get_node("_Components").add_child(component)

	target.actor._collect_components()

	var source := track(Actor.new()) as Actor
	source.global_position.x = 100.0
	var hit := HitData.new(40.0, source)

	assert_true(guard.start_parry())
	assert_eq(target.hurtbox.receive_hit(hit), 0.0)
	assert_eq(target.health.get_current_health(), 100.0)
	assert_false(guard.is_parrying())
	assert_false(guard.start_parry())

	guard._process(guard.config.parry_cooldown)
	assert_true(guard.start_parry())


func test_held_guard_transitions_from_parry_to_block() -> void:
	var target := _create_target(100.0)
	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [input, facing, guard]:
		target.actor.get_node("_Components").add_child(component)

	target.actor._collect_components()
	input._guard_just_pressed = true
	input._guard_pressed = true
	guard._process(0.0)

	assert_true(guard.is_parrying())
	assert_false(guard.is_guarding())

	guard._process(guard.config.parry_window)
	assert_false(guard.is_parrying())
	assert_true(guard.is_guarding())


func test_block_reaction_pulses_and_restores_visual() -> void:
	var target := _create_target(100.0)
	var visual := Node2D.new()
	visual.name = "_Visual"
	visual.scale = Vector2(1.5, 1.5)
	target.actor.add_child(visual)

	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()
	var reaction := BlockReactionComponent.new()
	var reaction_config := BlockReactionConfig.new()
	reaction_config.duration = 0.1
	reaction_config.scale_multiplier = Vector2(0.9, 1.1)
	reaction.config = reaction_config

	for component: Component in [input, facing, guard, reaction]:
		target.actor.get_node("_Components").add_child(component)

	target.actor._collect_components()
	reaction._ready()
	assert_true(guard.start_guard())

	var source := track(Actor.new()) as Actor
	source.global_position.x = 100.0
	target.hurtbox.receive_hit(HitData.new(20.0, source))

	assert_true(reaction.is_reacting())
	assert_true(visual.scale.is_equal_approx(Vector2(1.35, 1.65)))

	reaction._process(reaction_config.duration)

	assert_false(reaction.is_reacting())
	assert_true(visual.scale.is_equal_approx(Vector2(1.5, 1.5)))


func test_debug_overlay_reports_guard_state() -> void:
	var target := _create_target(100.0)
	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()

	for component: Component in [input, facing, guard]:
		target.actor.get_node("_Components").add_child(component)

	target.actor._collect_components()

	var overlay := DebugOverlayComponent.new()
	overlay.actor = target.actor
	var lines := PackedStringArray()
	overlay._append_guard_info(lines)
	assert_true(lines.has("Guard: READY"))

	guard.start_guard()
	lines.clear()
	overlay._append_guard_info(lines)
	assert_true(lines.has("Guard: GUARDING"))

	guard.stop_guard()
	guard.start_parry()
	lines.clear()
	overlay._append_guard_info(lines)
	assert_true(lines.has("Guard: PARRYING"))

	guard.disable()
	lines.clear()
	overlay._append_guard_info(lines)
	assert_true(lines.has("Guard: DISABLED"))


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
