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

	var overlay := track(DebugOverlayComponent.new()) as DebugOverlayComponent
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_progression_info(lines)
	assert_true(lines.has("Level: 3  XP: 10 / 225"))


func _capped_actor(max_level: int) -> ProgressionComponent:
	var actor := track(Actor.new()) as Actor
	var components := Node2D.new()
	components.name = "_Components"
	actor.add_child(components)
	var progression := ProgressionComponent.new()
	var config := ProgressionConfig.new()
	config.max_level = max_level
	progression.config = config
	components.add_child(progression)
	actor._collect_components()
	return progression


func test_default_curve_matches_the_documented_table() -> void:
	var progression := _capped_actor(ProgressionConfig.ABSOLUTE_MAX_LEVEL)
	assert_eq(progression.get_max_level(), 100)
	var expectations := {
		1: 100, 2: 105, 5: 122, 10: 155, 25: 323,
		50: 1092, 75: 3698, 99: 11928,
	}
	var total := 0
	for level in range(1, 100):
		assert_eq(progression.get_level(), level)
		var required := progression.get_experience_required()
		if expectations.has(level):
			assert_eq(required, expectations[level])
		total += required
		progression.gain_experience(required)
	assert_eq(progression.get_level(), 100)
	assert_true(progression.is_max_level())
	assert_eq(total, 248481)


func test_experience_to_max_level_is_the_cumulative_table_total() -> void:
	var progression := _capped_actor(ProgressionConfig.ABSOLUTE_MAX_LEVEL)
	assert_eq(progression.get_experience_to_max_level(), 248481)


func test_level_cap_stops_levels_and_discards_further_experience() -> void:
	var progression := _capped_actor(5)
	var reached_levels: Array[int] = []
	progression.leveled_up.connect(func(_previous: int, current: int) -> void:
		reached_levels.append(current)
	)
	assert_eq(progression.gain_experience(1000000), 4)
	assert_eq(progression.get_level(), 5)
	assert_true(progression.is_max_level())
	assert_eq(progression.get_experience(), 0)
	assert_eq(progression.get_experience_required(), 0)
	# Одно начисление сообщает о повышении один раз, но на потолке оно обязано
	# произойти: иначе достижение 100-го уровня прошло бы без обратной связи.
	assert_eq(reached_levels, [5])
	assert_true(progression.is_leveling_up())
	assert_eq(progression.gain_experience(500), 0)
	assert_eq(progression.get_experience(), 0)


func test_restore_clamps_level_and_experience_to_the_cap() -> void:
	var progression := _capped_actor(10)
	progression.restore_runtime_state({"level": 4200, "experience": 90})
	assert_eq(progression.get_level(), 10)
	assert_eq(progression.get_experience(), 0)
	assert_true(progression.is_max_level())

	var below := _capped_actor(10)
	below.restore_runtime_state({"level": 3, "experience": 9999})
	assert_eq(below.get_level(), 3)
	assert_eq(below.get_experience(), below.get_experience_required() - 1)


func test_overlay_reports_the_max_level_without_a_threshold() -> void:
	var progression := _capped_actor(2)
	progression.gain_experience(100)
	var actor := progression.get_parent().get_parent() as Actor
	var overlay := track(DebugOverlayComponent.new()) as DebugOverlayComponent
	overlay.actor = actor
	var lines := PackedStringArray()
	overlay._append_progression_info(lines)
	assert_true(lines.has("Level: 2  XP: MAX"))
