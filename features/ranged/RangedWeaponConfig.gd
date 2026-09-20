extends Resource
class_name RangedWeaponConfig

## Legacy component defaults. Equipped weapons use ItemWeaponProfile.ranged.
## aim_default_angle_degrees is the elevation a fresh bow or crossbow aim starts
## from; a remembered shot angle overrides it inside the aiming memory window.

@export_range(0.0, 3000.0) var arrow_gravity: float = 350.0
@export_range(0.0, 3000.0) var bolt_gravity: float = 50.0

@export_range(0.01, 2.0, 0.01) var release_duration: float = 0.12
@export_range(-90.0, 90.0) var aim_default_angle_degrees: float = 0.0
@export_range(0.0, 5.0, 0.01) var shot_cooldown: float = 0.3
@export_range(1.0, 2000.0, 1.0) var arrow_speed: float = 600.0
@export_range(1.0, 2000.0, 1.0) var bolt_speed: float = 820.0
@export_range(0.01, 10.0, 0.01) var projectile_lifetime: float = 2.0
@export_range(0.0, 100000.0, 1.0) var arrow_damage: float = 18.0
@export_range(0.0, 100000.0, 1.0) var bolt_damage: float = 24.0
@export_range(0.0, 1000.0, 1.0) var knockback: float = 160.0
