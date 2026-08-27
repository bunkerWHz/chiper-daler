extends Resource
class_name HitStunConfig

@export_range(0.01, 2.0, 0.01) var duration: float = 0.18
@export_range(0.01, 5.0, 0.01) var knockdown_duration: float = 0.65
@export_range(1.0, 2000.0, 1.0) var knockdown_velocity_threshold: float = 300.0
