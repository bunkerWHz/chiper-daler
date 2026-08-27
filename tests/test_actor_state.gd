@tool
extends McpTestSuite

const WALL_JUMP_CALCULATOR := preload(
	"res://features/movement/WallJumpCalculator.gd"
)


func suite_name() -> String:
	return "actor_state"


func test_actor_state_taxonomy_contains_planned_layers() -> void:
	assert_eq(
		ActorState.get_locomotion_name(ActorState.Locomotion.DOUBLE_JUMPING),
		"DoubleJumping"
	)
	assert_eq(
		ActorState.get_action_name(ActorState.Action.MAGIC_CHANNELING),
		"MagicChanneling"
	)


func test_actor_state_conditions_can_overlap() -> void:
	var conditions := (
		ActorState.Condition.STUNNED
		| ActorState.Condition.DEBUFFED
	)

	assert_true(
		ActorState.has_condition(conditions, ActorState.Condition.STUNNED)
	)
	assert_true(
		ActorState.has_condition(conditions, ActorState.Condition.DEBUFFED)
	)
	assert_false(
		ActorState.has_condition(conditions, ActorState.Condition.BUFFED)
	)
	assert_eq(ActorState.get_condition_names(conditions).size(), 2)


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

	movement._set_state(MovementState.Type.RUN)
	actor_state.refresh_state()
	assert_eq(actor_state.get_locomotion(), ActorState.Locomotion.WALKING)

	movement._set_state(MovementState.Type.JUMP)
	actor_state.refresh_state()
	assert_eq(actor_state.get_locomotion(), ActorState.Locomotion.JUMPING)

	movement._set_state(MovementState.Type.DOUBLE_JUMP)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_locomotion(),
		ActorState.Locomotion.DOUBLE_JUMPING
	)

	movement._set_state(MovementState.Type.WALL_JUMP)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_locomotion(),
		ActorState.Locomotion.WALL_JUMPING
	)

	movement._set_state(MovementState.Type.DODGE)
	actor_state.refresh_state()
	assert_eq(
		actor_state.get_locomotion(),
		ActorState.Locomotion.DODGING
	)

	movement._set_state(MovementState.Type.FALL)
	actor_state.refresh_state()
	assert_eq(actor_state.get_locomotion(), ActorState.Locomotion.FALLING)


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
	assert_true(actor_state.has_condition(ActorState.Condition.DEAD))

	var overlay := DebugOverlayComponent.new()
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_actor_state_info(lines)

	assert_true(lines.has("States: Idle + Dead"))
	assert_false(overlay.should_disable_on_actor_death())


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
