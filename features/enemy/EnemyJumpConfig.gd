extends Resource
class_name EnemyJumpConfig

@export_range(1.0, 2000.0, 1.0) var jump_velocity: float = 450.0
@export_range(0.0, 5.0, 0.05) var cooldown: float = 0.5
@export_range(0.0, 200.0, 1.0) var min_upward_offset: float = 12.0
@export_range(0.0, 100.0, 1.0) var landing_tolerance: float = 16.0
@export var jump_at_unsafe_ground: bool = true
@export var require_landing_surface: bool = true
@export_range(0.0, 100.0, 1.0) var landing_probe_up: float = 16.0
@export_range(1.0, 200.0, 1.0) var landing_probe_depth: float = 80.0
