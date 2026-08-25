extends Resource
class_name HitStopConfig

@export_range(0.01, 0.2, 0.01) var duration: float = 0.05
@export_range(0.01, 1.0, 0.01) var time_scale: float = 0.05
@export var on_hit_landed: bool = true
@export var on_hit_received: bool = true
