extends Resource
class_name ItemAmmunitionProfile

@export var ammunition_type: StringName
## Projectile scene this ammunition flies as: artwork, collision, sticks and
## pierce are authored there. Empty falls back to the generic
## `features/projectiles/Projectile.tscn`.
@export var projectile_scene: PackedScene


func is_valid() -> bool:
	return not ammunition_type.is_empty()
