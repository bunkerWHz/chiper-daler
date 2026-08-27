extends Resource
class_name DodgeConfig

@export_range(1.0, 2000.0, 1.0) var speed: float = 420.0
@export_range(0.01, 2.0, 0.01) var duration: float = 0.18
@export_range(0.0, 5.0, 0.01) var cooldown: float = 0.35
@export_range(0.0, 2.0, 0.01) var invulnerability_duration: float = 0.15
@export var allow_air_dodge: bool = true
