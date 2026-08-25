@tool
extends McpTestSuite


func suite_name() -> String:
	return "jump_trajectory"


func test_running_jump_matches_player_reach() -> void:
	var config := MovementConfig.new()
	var points := JumpTrajectoryCalculator.sample_jump(config, 1.0, true)
	var apex := JumpTrajectoryCalculator.get_apex(points)
	var landing := JumpTrajectoryCalculator.get_landing_point(points)

	assert_true(apex.y < -75.0)
	assert_true(apex.y > -90.0)
	assert_true(landing.x > 140.0)
	assert_true(landing.x < 160.0)
	assert_true(is_zero_approx(landing.y))


func test_standing_jump_is_shorter_with_smooth_acceleration() -> void:
	var config := MovementConfig.new()
	var running := JumpTrajectoryCalculator.sample_jump(config, 1.0, true)
	var standing := JumpTrajectoryCalculator.sample_jump(config, 1.0, false)
	var running_landing := JumpTrajectoryCalculator.get_landing_point(running)
	var standing_landing := JumpTrajectoryCalculator.get_landing_point(standing)

	assert_true(standing_landing.x < running_landing.x)
	assert_true(standing_landing.x > 100.0)


func test_jump_trajectory_is_symmetric() -> void:
	var config := MovementConfig.new()
	var right := JumpTrajectoryCalculator.sample_jump(config, 1.0, true)
	var left := JumpTrajectoryCalculator.sample_jump(config, -1.0, true)
	var right_landing := JumpTrajectoryCalculator.get_landing_point(right)
	var left_landing := JumpTrajectoryCalculator.get_landing_point(left)

	assert_true(absf(right_landing.x + left_landing.x) < 0.001)
	assert_true(absf(right_landing.y - left_landing.y) < 0.001)
