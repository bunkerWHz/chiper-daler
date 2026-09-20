extends Resource
class_name AimingConfig

@export_range(-90.0, 90.0) var default_angle_degrees: float = 5.0
@export_range(1.0, 360.0) var angular_speed_degrees: float = 90.0
@export_range(0.01, 5.0) var mouse_degrees_per_pixel: float = 0.25
@export_range(0.0, 1.0) var hold_delay: float = 0.15
@export var launch_offset: Vector2 = Vector2(0, -12)
## Window in which a new aim session reuses the angle of the last released shot.
## Zero disables the memory.
@export_range(0.0, 10.0) var angle_memory_duration: float = 2.0
## Distance in world units that counts as movement and drops the remembered angle.
@export_range(0.0, 64.0) var angle_memory_move_tolerance: float = 0.5
