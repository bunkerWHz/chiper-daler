@tool
extends Resource
class_name ItemRangedProfile

@export_range(1.0, 5000.0, 1.0) var projectile_speed: float = 600.0
@export_range(0.0, 3000.0, 1.0) var projectile_gravity: float = 350.0
## Added to the equipped weapon's damage, including its upgrades.
@export_range(0.0, 100000.0, 1.0) var projectile_damage: float = 18.0
@export_range(0.01, 10.0, 0.01) var projectile_lifetime: float = 2.0
@export_range(0.0, 5.0, 0.01) var shot_cooldown: float = 0.3
@export_range(0.01, 2.0, 0.01) var release_duration: float = 0.12
@export_range(0.0, 1000.0, 1.0) var knockback: float = 160.0


static func create_defaults(crossbow: bool = false) -> ItemRangedProfile:
	var result := ItemRangedProfile.new()
	if crossbow:
		result.projectile_speed = 820.0
		result.projectile_gravity = 50.0
		result.projectile_damage = 24.0
	return result


func is_valid() -> bool:
	return (is_finite(projectile_speed) and projectile_speed > 0.0
		and is_finite(projectile_gravity) and projectile_gravity >= 0.0
		and is_finite(projectile_damage) and projectile_damage >= 0.0
		and is_finite(projectile_lifetime) and projectile_lifetime > 0.0
		and is_finite(shot_cooldown) and shot_cooldown >= 0.0
		and is_finite(release_duration) and release_duration > 0.0
		and is_finite(knockback) and knockback >= 0.0)
