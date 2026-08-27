@tool
extends McpTestSuite


func suite_name() -> String:
	return "climbing"


func test_climbing_requires_vertical_input_and_stops_gravity_velocity() -> void:
	var setup := _create_climbing_actor()
	var input := setup.input as InputComponent
	var body := setup.body as CharacterBodyComponent
	var climbing := setup.climbing as ClimbingComponent
	var climbable := setup.climbable as ClimbableArea

	climbing.enter_climbable(climbable)
	assert_false(climbing.is_climbing())

	input._vertical_axis = -1.0
	climbing._physics_process(0.0)
	climbing.apply_velocity()

	assert_true(climbing.is_climbing())
	assert_eq(climbing.get_vertical_direction(), -1.0)
	assert_eq(body.get_velocity(), Vector2(0.0, -climbing.config.climb_speed))


func test_climbing_idle_and_down_directions_are_exposed() -> void:
	var setup := _create_climbing_actor()
	var input := setup.input as InputComponent
	var climbing := setup.climbing as ClimbingComponent
	var climbable := setup.climbable as ClimbableArea

	climbing.enter_climbable(climbable)
	input._vertical_axis = 1.0
	assert_true(climbing.start_climbing(climbable))
	assert_eq(climbing.get_vertical_direction(), 1.0)

	input._vertical_axis = 0.0
	climbing._physics_process(0.0)
	assert_eq(climbing.get_vertical_direction(), 0.0)


func test_jump_exits_climbing_with_impulse() -> void:
	var setup := _create_climbing_actor()
	var input := setup.input as InputComponent
	var body := setup.body as CharacterBodyComponent
	var climbing := setup.climbing as ClimbingComponent
	var climbable := setup.climbable as ClimbableArea

	climbing.enter_climbable(climbable)
	input._vertical_axis = -1.0
	assert_true(climbing.start_climbing(climbable))
	input._jump_pressed = true
	climbing._physics_process(0.0)

	assert_false(climbing.is_climbing())
	assert_true(climbing.is_exiting_climb())
	assert_false(climbing.can_start_climbing())
	assert_eq(body.get_velocity(), Vector2(
		climbing.config.exit_jump_horizontal_velocity,
		-climbing.config.exit_jump_vertical_velocity
	))


func test_leaving_area_stops_climbing() -> void:
	var setup := _create_climbing_actor()
	var climbing := setup.climbing as ClimbingComponent
	var climbable := setup.climbable as ClimbableArea

	climbing.enter_climbable(climbable)
	assert_true(climbing.start_climbing(climbable))
	climbing.exit_climbable(climbable)

	assert_false(climbing.is_climbing())


func _create_climbing_actor() -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var body := CharacterBodyComponent.new()
	var character_body := CharacterBody2D.new()
	character_body.name = "CharacterBody2D"
	body.add_child(character_body)
	var facing := FacingComponent.new()
	var climbing_script := ResourceLoader.load(
		"res://features/movement/ClimbingComponent.gd",
		"GDScript",
		ResourceLoader.CACHE_MODE_IGNORE
	) as GDScript
	var climbing: Variant = climbing_script.new()
	climbing.config = ClimbingConfig.new()
	var climbable := track(ClimbableArea.new()) as ClimbableArea

	components.add_child(input)
	components.add_child(body)
	components.add_child(facing)
	components.add_child(climbing)
	actor._collect_components()

	return {
		"actor": actor,
		"input": input,
		"body": body,
		"facing": facing,
		"climbing": climbing,
		"climbable": climbable,
	}
