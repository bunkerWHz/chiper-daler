@tool
extends McpTestSuite


func suite_name() -> String:
	return "progression"


func test_experience_can_gain_multiple_levels_and_reports_state() -> void:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)

	var progression := ProgressionComponent.new()
	var config := ProgressionConfig.new()
	config.initial_experience_required = 100
	config.requirement_growth = 1.5
	progression.config = config
	var state := ActorStateComponent.new()
	components.add_child(progression)
	components.add_child(state)
	actor._collect_components()

	assert_eq(progression.gain_experience(260), 2)
	assert_eq(progression.get_level(), 3)
	assert_eq(progression.get_experience(), 10)
	assert_eq(progression.get_experience_required(), 225)
	state.refresh_state()
	assert_eq(state.get_state(), ActorState.Behavior.LEVEL_UP)

	progression._process(config.level_up_state_duration)
	state.refresh_state()
	assert_false(progression.is_leveling_up())
	assert_eq(state.get_state(), ActorState.Behavior.IDLE)

	var overlay := DebugOverlayComponent.new()
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_progression_info(lines)
	assert_true(lines.has("Level: 3  XP: 10 / 225"))
