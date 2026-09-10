extends Resource
class_name EnemyChaseConfig

## Half extents in actor-local pixels, scaled with the Actor root.
@export_range(1.0, 1000.0, 1.0, "or_greater") var horizontal_range: float = 180.0
@export_range(1.0, 500.0, 1.0, "or_greater") var vertical_range: float = 80.0
@export var avoid_unsafe_ground: bool = true
