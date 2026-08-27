extends Resource
class_name ClimbingConfig

@export_range(1.0, 1000.0, 1.0) var climb_speed: float = 120.0
@export_range(1.0, 1000.0, 1.0) var exit_jump_horizontal_velocity: float = 180.0
@export_range(1.0, 1000.0, 1.0) var exit_jump_vertical_velocity: float = 350.0
@export_range(0.0, 1.0, 0.01) var exit_control_lock_time: float = 0.12
