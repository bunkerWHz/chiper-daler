extends Resource
class_name EnemyFlightConfig

@export_range(0.0, 1000.0, 1.0) var move_speed: float = 75.0
@export_range(0.0, 5000.0, 1.0) var acceleration: float = 450.0
@export var initial_direction: Vector2 = Vector2.LEFT
@export_range(0.0, 1000.0, 1.0) var patrol_distance: float = 90.0
@export_range(0.0, 1000.0, 1.0) var patrol_vertical_amplitude: float = 12.0
@export_range(0.0, 10.0, 0.05) var patrol_vertical_frequency: float = 1.2
@export_range(0.0, 1000.0, 1.0) var target_stopping_distance: float = 24.0
