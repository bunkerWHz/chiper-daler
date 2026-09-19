extends Resource
class_name ItemProjectileProfile

@export var texture: Texture2D
## Applied through the target's hurtbox after a damaging hit. Empty means no effects.
@export var status_effects: Array[StatusEffect] = []
## Spin in degrees per second. Zero follows the flight direction without spinning.
@export_range(-3600.0, 3600.0, 1.0, "or_less", "or_greater", "suffix:°/s") var rotation_speed: float = 0.0
@export_range(1.0, 3000.0) var speed: float = 520.0
@export_range(0.0, 3000.0) var gravity: float = 700.0
@export_range(0.01, 30.0) var lifetime: float = 3.0
@export_range(0.0, 100000.0) var damage: float = 20.0
@export_range(0.0, 1000.0) var knockback: float = 220.0


func is_valid() -> bool:
	return speed > 0.0 and gravity >= 0.0 and lifetime > 0.0 and damage >= 0.0 and knockback >= 0.0
