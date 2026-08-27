extends RefCounted
class_name HitData

var damage: float
var source_actor: Actor
var knockback_velocity: Vector2
var is_critical: bool


func _init(
	hit_damage: float,
	source: Actor,
	hit_knockback_velocity: Vector2 = Vector2.ZERO,
	hit_is_critical: bool = false
) -> void:
	damage = hit_damage
	source_actor = source
	knockback_velocity = hit_knockback_velocity
	is_critical = hit_is_critical
