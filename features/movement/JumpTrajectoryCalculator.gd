extends RefCounted
class_name JumpTrajectoryCalculator


static func sample_jump(
	config: MovementConfig,
	direction: float,
	start_at_full_speed: bool,
	physics_fps: float = 60.0,
	max_time: float = 2.0
) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])

	if (
		config == null
		or config.gravity <= 0.0
		or config.jump_velocity <= 0.0
		or physics_fps <= 0.0
		or max_time <= 0.0
	):
		return points

	var horizontal_direction := signf(direction)
	var target_speed := horizontal_direction * config.move_speed
	var velocity := Vector2(
		target_speed if start_at_full_speed else 0.0,
		-config.jump_velocity
	)
	var position := Vector2.ZERO
	var delta := 1.0 / physics_fps
	var max_steps := ceili(max_time * physics_fps)
	var left_ground := false

	for _step in max_steps:
		velocity.x = _update_horizontal_velocity(
			config,
			velocity.x,
			target_speed,
			delta
		)
		velocity.y += config.gravity * delta

		var previous_position := position
		position += velocity * delta

		if position.y < 0.0:
			left_ground = true

		if left_ground and position.y >= 0.0 and velocity.y > 0.0:
			points.append(_interpolate_landing(previous_position, position))
			break

		points.append(position)

	return points


static func get_apex(points: PackedVector2Array) -> Vector2:
	var apex := Vector2.ZERO

	for point: Vector2 in points:
		if point.y < apex.y:
			apex = point

	return apex


static func get_landing_point(points: PackedVector2Array) -> Vector2:
	return points[-1] if not points.is_empty() else Vector2.ZERO


static func get_horizontal_reach_at_height(
	move_speed: float,
	gravity: float,
	jump_velocity: float,
	vertical_offset: float
) -> float:
	if move_speed < 0.0 or gravity <= 0.0 or jump_velocity <= 0.0:
		return 0.0

	return move_speed * get_flight_time_at_height(
		gravity,
		jump_velocity,
		vertical_offset
	)


static func get_flight_time_at_height(
	gravity: float,
	jump_velocity: float,
	vertical_offset: float
) -> float:
	if gravity <= 0.0 or jump_velocity <= 0.0:
		return 0.0

	var discriminant := (
		jump_velocity * jump_velocity
		+ 2.0 * gravity * vertical_offset
	)

	if discriminant < 0.0:
		return 0.0

	return (
		jump_velocity + sqrt(discriminant)
	) / gravity


static func can_reach_height(
	gravity: float,
	jump_velocity: float,
	vertical_offset: float
) -> bool:
	if gravity <= 0.0 or jump_velocity <= 0.0:
		return false

	var max_jump_height := jump_velocity * jump_velocity / (2.0 * gravity)
	return vertical_offset >= -max_jump_height


static func _update_horizontal_velocity(
	config: MovementConfig,
	current_speed: float,
	target_speed: float,
	delta: float
) -> float:
	if config.acceleration_mode == MovementConfig.AccelerationMode.INSTANT:
		return target_speed

	return move_toward(current_speed, target_speed, config.acceleration * delta)


static func _interpolate_landing(
	previous_position: Vector2,
	current_position: Vector2
) -> Vector2:
	var vertical_distance := current_position.y - previous_position.y

	if is_zero_approx(vertical_distance):
		return Vector2(current_position.x, 0.0)

	var weight := clampf(-previous_position.y / vertical_distance, 0.0, 1.0)
	var landing := previous_position.lerp(current_position, weight)
	landing.y = 0.0
	return landing
