extends Resource
class_name RangedWeaponConfig

@export_range(0.01, 2.0, 0.01) var release_duration: float = 0.12
@export_range(0.0, 5.0, 0.01) var shot_cooldown: float = 0.3
@export_range(1.0, 2000.0, 1.0) var arrow_speed: float = 680.0
@export_range(1.0, 2000.0, 1.0) var bolt_speed: float = 820.0
@export_range(0.01, 10.0, 0.01) var projectile_lifetime: float = 2.0
@export_range(0.0, 100000.0, 1.0) var arrow_damage: float = 18.0
@export_range(0.0, 100000.0, 1.0) var bolt_damage: float = 24.0
@export_range(0.0, 1000.0, 1.0) var knockback: float = 160.0
@export_range(0, 999, 1) var arrow_count: int = 20
@export_range(0, 999, 1) var bolt_count: int = 12
