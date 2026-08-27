extends Resource
class_name ThrowingConfig

@export_range(0.01, 2.0, 0.01) var action_duration: float = 0.08
@export_range(0.01, 2.0, 0.01) var recovery_duration: float = 0.25
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 520.0
@export_range(0.01, 10.0, 0.01) var projectile_lifetime: float = 1.5
@export_range(0.0, 100000.0, 1.0) var damage: float = 20.0
@export_range(0.0, 1000.0, 1.0) var knockback: float = 220.0
@export_range(0, 99, 1) var max_charges: int = 5
