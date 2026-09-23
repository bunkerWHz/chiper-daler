@tool
extends McpTestSuite


class GroundStateBodyComponent:
	extends CharacterBodyComponent

	var grounded: bool = true


	func is_on_floor() -> bool:
		return grounded


func suite_name() -> String:
	return "dodge"


func test_air_dodge_moves_in_input_direction_and_grants_invulnerability() -> void:
	var setup := _create_dodge_actor()
	var input := setup.input as InputComponent
	var body := setup.body as CharacterBodyComponent
	var dodge := setup.dodge as DodgeComponent
	var invulnerability: Variant = setup.invulnerability

	input._move_axis = -1.0

	assert_true(dodge.try_start_dodge())
	assert_true(dodge.is_dodging())
	assert_eq(dodge.get_direction(), -1.0)
	assert_true(invulnerability.is_invulnerable())

	dodge.apply_velocity()
	assert_eq(body.get_velocity(), Vector2(-dodge.config.speed, 0.0))


func test_air_dodge_is_limited_until_landing() -> void:
	var setup := _create_dodge_actor()
	var dodge := setup.dodge as DodgeComponent

	assert_true(dodge.try_start_dodge())
	dodge._physics_process(dodge.config.duration)
	dodge._physics_process(dodge.config.cooldown)

	assert_false(dodge.is_dodging())
	assert_false(dodge.can_dodge())

	dodge._air_dodge_available = true
	assert_true(dodge.can_dodge())


func test_roll_and_air_dodge_use_separate_durations() -> void:
	var config := DodgeConfig.new()
	config.duration = 0.2
	config.roll_duration = 0.6
	assert_eq(config.get_duration(true), 0.2)
	assert_eq(config.get_duration(false), 0.6)
	# An uninitialized component reports the ground roll, not the air dodge.
	var dodge := track(DodgeComponent.new()) as DodgeComponent
	assert_false(dodge.is_air_dodge())


func test_ground_dodge_is_the_roll_and_outlasts_the_air_dodge() -> void:
	var ground := _create_dodge_actor(true)
	var air := _create_dodge_actor(false)
	var roll := ground.dodge as DodgeComponent
	var jump := air.dodge as DodgeComponent

	assert_true(roll.try_start_dodge())
	assert_true(jump.try_start_dodge())
	assert_false(roll.is_air_dodge())
	assert_true(jump.is_air_dodge())

	jump._physics_process(jump.config.duration)
	assert_false(jump.is_dodging())
	assert_true(roll.is_dodging(), "The roll must outlast the shorter air dodge")

	roll._physics_process(roll.config.roll_duration)
	assert_false(roll.is_dodging())


func test_dodge_falls_back_to_facing_direction() -> void:
	var setup := _create_dodge_actor()
	var dodge := setup.dodge as DodgeComponent
	var facing := setup.facing as FacingComponent

	facing._set_direction(FacingComponent.Direction.LEFT)

	assert_true(dodge.try_start_dodge())
	assert_eq(dodge.get_direction(), -1.0)


func test_dodge_does_not_shorten_existing_invulnerability() -> void:
	var setup := _create_dodge_actor()
	var dodge := setup.dodge as DodgeComponent
	var invulnerability: Variant = setup.invulnerability

	invulnerability.activate(0.6)
	assert_true(dodge.try_start_dodge())
	assert_eq(invulnerability._timer, 0.6)


func _create_dodge_actor(grounded: bool = false) -> Dictionary:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var input := InputComponent.new()
	var body: CharacterBodyComponent
	if grounded:
		var ground_body := GroundStateBodyComponent.new()
		ground_body.grounded = true
		body = ground_body
	else:
		body = CharacterBodyComponent.new()
	var character_body := CharacterBody2D.new()
	character_body.name = "CharacterBody2D"
	body.add_child(character_body)
	var facing := FacingComponent.new()
	var invulnerability_script := ResourceLoader.load(
		"res://features/combat/InvulnerabilityComponent.gd",
		"GDScript",
		ResourceLoader.CACHE_MODE_IGNORE
	) as GDScript
	var invulnerability: Variant = invulnerability_script.new()
	invulnerability.config = InvulnerabilityConfig.new()
	invulnerability.config.blink_visual = false
	var dodge := DodgeComponent.new()
	dodge.config = DodgeConfig.new()

	components.add_child(input)
	components.add_child(body)
	components.add_child(facing)
	components.add_child(invulnerability)
	components.add_child(dodge)
	actor._collect_components()

	return {
		"actor": actor,
		"input": input,
		"body": body,
		"facing": facing,
		"invulnerability": invulnerability,
		"dodge": dodge,
	}
