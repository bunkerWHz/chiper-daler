@tool
extends McpTestSuite

const WALL_JUMP_CALCULATOR := preload(
	"res://features/movement/WallJumpCalculator.gd"
)


class GroundStateBodyComponent:
	extends CharacterBodyComponent

	var grounded: bool = true


	func is_on_floor() -> bool:
		return grounded


	func move_and_slide() -> void:
		pass


func suite_name() -> String:
	return "actor_state"


func test_actor_state_taxonomy_contains_exclusive_behaviors() -> void:
	assert_eq(
		ActorState.get_behavior_name(ActorState.Behavior.DOUBLE_JUMP),
		"DoubleJump"
	)
	assert_eq(
		ActorState.get_behavior_name(ActorState.Behavior.MAGIC_CHANNELING),
		"MagicChanneling"
	)
	assert_eq(
		ActorState.get_behavior_name(ActorState.Behavior.AIR_LIGHT_ATTACK),
		"AirLightAttack"
	)


func test_actor_statuses_can_overlap_without_creating_extra_states() -> void:
	var statuses := ActorState.Status.DEBUFFED | ActorState.Status.BUFFED

	assert_true(
		ActorState.has_status(statuses, ActorState.Status.DEBUFFED)
	)
	assert_true(
		ActorState.has_status(statuses, ActorState.Status.BUFFED)
	)
	assert_false(
		ActorState.has_status(statuses, ActorState.Status.NONE)
	)
	assert_eq(ActorState.get_status_names(statuses).size(), 2)


func test_actor_state_component_maps_existing_movement_states() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	components.add_child(body_component)
	components.add_child(InputComponent.new())

	var movement: Variant = _create_fresh_movement_component()
	movement.config = MovementConfig.new()
	components.add_child(movement)

	var actor_state := ActorStateComponent.new()
	components.add_child(actor_state)
	actor._collect_components()

	var mappings := {
		MovementState.Type.RUN: ActorState.Behavior.RUN,
		MovementState.Type.JUMP: ActorState.Behavior.JUMP,
		MovementState.Type.DOUBLE_JUMP: ActorState.Behavior.DOUBLE_JUMP,
		MovementState.Type.WALL_JUMP: ActorState.Behavior.WALL_JUMP,
		MovementState.Type.DODGE: ActorState.Behavior.DODGE,
		MovementState.Type.CLIMB_IDLE: ActorState.Behavior.CLIMB_IDLE,
		MovementState.Type.CLIMB_UP: ActorState.Behavior.CLIMB_UP,
		MovementState.Type.CLIMB_DOWN: ActorState.Behavior.CLIMB_DOWN,
		MovementState.Type.FALL: ActorState.Behavior.FALL,
	}

	for movement_state: MovementState.Type in mappings:
		movement._set_state(movement_state)
		actor_state.refresh_state()
		assert_eq(actor_state.get_state(), mappings[movement_state])


func test_actor_state_component_survives_death_and_reports_it() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var health := HealthComponent.new()
	var health_config := HealthConfig.new()
	health_config.max_health = 10.0
	health.config = health_config
	components.add_child(health)

	var death := DeathComponent.new()
	var death_config := DeathConfig.new()
	death_config.fade_visual = false
	death_config.remove_actor_on_finish = false
	death.config = death_config
	components.add_child(death)

	var actor_state := ActorStateComponent.new()
	components.add_child(actor_state)
	actor._collect_components()

	health.take_damage(10.0)
	actor_state.refresh_state()

	assert_true(actor_state.is_enabled)
	assert_eq(actor_state.get_state(), ActorState.Behavior.DEAD)

	var overlay := DebugOverlayComponent.new()
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_actor_state_info(lines)

	assert_true(lines.has("State: Dead"))
	assert_false(overlay.should_disable_on_actor_death())


func test_actor_state_maps_heavy_attack_and_parry() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var facing := FacingComponent.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var guard := GuardComponent.new()
	guard.config = GuardConfig.new()
	var actor_state := ActorStateComponent.new()

	for component: Component in [
		input,
		facing,
		hitbox,
		attack,
		guard,
		actor_state,
	]:
		components.add_child(component)

	actor._collect_components()
	hitbox._ready()
	attack._ready()

	input._attack_just_pressed = true
	input._attack_pressed = true
	attack._process(0.0)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_state(),
		ActorState.Behavior.GROUND_ATTACK_WINDUP
	)

	assert_true(attack.heavy_attack())
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_state(),
		ActorState.Behavior.GROUND_HEAVY_ATTACK
	)

	attack._process(attack.config.heavy_active_duration)
	assert_true(guard.start_parry())
	actor_state.refresh_state()
	assert_eq(actor_state.get_state(), ActorState.Behavior.PARRYING)


func test_ground_attack_is_exclusive_and_stops_horizontal_movement() -> void:
	var setup := _create_attack_state_actor()
	var body := setup.body as GroundStateBodyComponent
	var movement := setup.movement as MovementComponent
	var attack := setup.attack as AttackComponent
	var state := setup.state as ActorStateComponent
	body.grounded = true
	body.set_velocity(Vector2(180.0, 0.0))

	assert_true(attack.attack())
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.GROUND_LIGHT_ATTACK)
	movement._physics_process(0.0)
	assert_eq(body.get_velocity().x, 0.0)

	attack._process(attack.config.active_duration)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.IDLE)


func test_air_attacks_return_to_air_motion_or_landing_recovery() -> void:
	var setup := _create_attack_state_actor()
	var input := setup.input as InputComponent
	var body := setup.body as GroundStateBodyComponent
	var movement := setup.movement as MovementComponent
	var attack := setup.attack as AttackComponent
	var state := setup.state as ActorStateComponent
	body.grounded = false
	body.set_velocity(Vector2(100.0, -100.0))
	movement._set_state(MovementState.Type.JUMP)

	input._attack_just_pressed = true
	input._attack_pressed = true
	attack._process(0.0)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.AIR_ATTACK_WINDUP)
	input._attack_pressed = false
	input._attack_released = true
	attack._process(0.0)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.AIR_LIGHT_ATTACK)
	attack._process(attack.config.active_duration)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.JUMP)

	attack._process(attack.config.cooldown)
	body.set_velocity(Vector2(100.0, 100.0))
	movement._set_state(MovementState.Type.FALL)
	assert_true(attack.heavy_attack())
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.AIR_HEAVY_ATTACK)

	body.grounded = true
	attack._process(0.0)
	state.refresh_state()
	assert_eq(
		state.get_state(),
		ActorState.Behavior.GROUND_ATTACK_RECOVERY
	)
	movement._physics_process(0.0)
	assert_eq(body.get_velocity().x, 0.0)
	attack._process(attack.config.landing_recovery_duration)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.IDLE)


func test_movement_consumes_exactly_one_air_jump() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var body_component := CharacterBodyComponent.new()
	var body := CharacterBody2D.new()
	body.name = "CharacterBody2D"
	body_component.add_child(body)
	components.add_child(body_component)
	components.add_child(InputComponent.new())

	var movement: Variant = _create_fresh_movement_component()
	movement.config = MovementConfig.new()
	components.add_child(movement)
	actor._collect_components()

	movement._coyote_timer = movement.config.coyote_time
	movement._jump_buffer_timer = movement.config.jump_buffer_time
	movement._update_jump()
	assert_eq(movement.get_jump_count(), 1)

	movement._jump_buffer_timer = movement.config.jump_buffer_time
	movement._update_jump()

	assert_eq(movement.get_jump_count(), 2)
	assert_eq(
		body_component.get_velocity().y,
		-movement.config.air_jump_velocity
	)

	movement._jump_buffer_timer = movement.config.jump_buffer_time
	movement._update_jump()
	assert_eq(movement.get_jump_count(), 2)


func test_wall_jump_velocity_pushes_away_from_wall() -> void:
	var left_wall_jump := WALL_JUMP_CALCULATOR.calculate_velocity(
		Vector2.RIGHT,
		260.0,
		450.0
	)
	var right_wall_jump := WALL_JUMP_CALCULATOR.calculate_velocity(
		Vector2.LEFT,
		260.0,
		450.0
	)

	assert_eq(left_wall_jump, Vector2(260.0, -450.0))
	assert_eq(right_wall_jump, Vector2(-260.0, -450.0))
	assert_eq(
		WALL_JUMP_CALCULATOR.calculate_velocity(Vector2.UP, 260.0, 450.0),
		Vector2.ZERO
	)


func _create_fresh_movement_component() -> Variant:
	var movement_script := ResourceLoader.load(
		"res://features/movement/MovementComponent.gd",
		"GDScript",
		ResourceLoader.CACHE_MODE_IGNORE
	) as GDScript
	return movement_script.new()


func _create_attack_state_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var input := InputComponent.new()
	var body := GroundStateBodyComponent.new()
	var character_body := CharacterBody2D.new()
	character_body.name = "CharacterBody2D"
	body.add_child(character_body)
	var movement := MovementComponent.new()
	movement.config = MovementConfig.new()
	var hitbox := HitboxComponent.new()
	var area := Area2D.new()
	area.name = "Area2D"
	hitbox.add_child(area)
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	var state := ActorStateComponent.new()
	for component: Component in [
		input,
		body,
		movement,
		hitbox,
		attack,
		state,
	]:
		components.add_child(component)
	actor._collect_components()
	hitbox._ready()
	attack._ready()
	return {
		"actor": actor,
		"input": input,
		"body": body,
		"movement": movement,
		"attack": attack,
		"state": state,
	}
