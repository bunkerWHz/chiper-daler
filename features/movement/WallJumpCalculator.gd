extends RefCounted


static func calculate_velocity(
	wall_normal: Vector2,
	horizontal_velocity: float,
	vertical_velocity: float
) -> Vector2:
	if absf(wall_normal.x) < 0.5:
		return Vector2.ZERO

	return Vector2(
		signf(wall_normal.x) * horizontal_velocity,
		-vertical_velocity
	)
