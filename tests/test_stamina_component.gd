@tool
extends McpTestSuite

func suite_name() -> String:
	return "stamina"

func test_spend_wait_and_regenerate() -> void:
	var actor := track(Actor.new()) as Actor
	var stamina := StaminaComponent.new()
	stamina.config = StaminaConfig.new()
	actor.add_child(stamina)
	stamina.initialize(actor)
	assert_eq(stamina.get_stamina(), 100.0)
	assert_true(stamina.spend(40.0))
	assert_eq(stamina.get_stamina(), 60.0)
	stamina._process(0.5)
	assert_eq(stamina.get_stamina(), 60.0)
	stamina._process(0.25)
	stamina._process(1.0)
	assert_eq(stamina.get_stamina(), 85.0)
	assert_false(stamina.spend(90.0))
