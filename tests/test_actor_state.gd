@tool
extends McpTestSuite


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

	var movement := MovementComponent.new()
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
