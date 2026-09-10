extends Resource
class_name EnemyGroundSensorConfig

## Distances in actor-local pixels, scaled with the Actor root.
@export_range(1.0, 100.0, 1.0, "or_greater") var ledge_check_distance: float = 14.0
@export_range(1.0, 100.0, 1.0, "or_greater") var floor_check_depth: float = 24.0
@export_range(1.0, 100.0, 1.0, "or_greater") var wall_check_distance: float = 16.0
