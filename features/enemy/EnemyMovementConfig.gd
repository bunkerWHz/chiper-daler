extends Resource
class_name EnemyMovementConfig

@export_range(0.0, 1000.0, 1.0) var move_speed: float = 100.0
@export_range(0.0, 5000.0, 1.0) var gravity: float = 1200.0
@export_range(-1.0, 1.0, 1.0) var initial_direction: float = 0.0
