extends Resource
class_name AttackConfig

@export_range(0.01, 2.0, 0.01) var active_duration: float = 0.12
@export_range(0.01, 5.0, 0.01) var cooldown: float = 0.3
@export_range(0.05, 2.0, 0.01) var heavy_charge_time: float = 0.35
@export_range(0.01, 2.0, 0.01) var heavy_active_duration: float = 0.22
@export_range(0.01, 5.0, 0.01) var heavy_cooldown: float = 0.65
@export_range(1.0, 10.0, 0.1) var heavy_damage_multiplier: float = 2.0
