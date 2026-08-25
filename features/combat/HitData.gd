extends RefCounted
class_name HitData

var damage: float
var source_actor: Actor
var knockback_velocity: Vector2


func _init(
	hit_damage: float,
	source: Actor,
	hit_knockback_velocity: Vector2 = Vector2.ZERO
) -> void:
	damage = hit_damage
	source_actor = source
	knockback_velocity = hit_knockback_velocity
