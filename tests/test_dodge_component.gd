@tool
extends McpTestSuite


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


func _create_dodge_actor() -> Dictionary:
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
