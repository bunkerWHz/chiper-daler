extends Resource
class_name MagicConfig

@export_range(0.01, 3.0, 0.01) var charge_time: float = 0.4
@export_range(0.01, 2.0, 0.01) var cast_duration: float = 0.12
@export_range(0.01, 3.0, 0.01) var recovery_duration: float = 0.3
@export_range(1.0, 2000.0, 1.0) var projectile_speed: float = 600.0
@export_range(0.01, 10.0, 0.01) var projectile_lifetime: float = 2.0
@export_range(0.0, 100000.0, 1.0) var damage: float = 28.0
@export_range(0.0, 1000.0, 1.0) var knockback: float = 120.0
@export_range(0, 999, 1) var max_mana: int = 100
@export_range(1, 999, 1) var cast_mana_cost: int = 20
@export_range(1, 999, 1) var channel_mana_per_second: float = 12.0
