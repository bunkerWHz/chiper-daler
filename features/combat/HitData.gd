extends RefCounted
class_name HitData

var damage: float
var source_actor: Actor


func _init(hit_damage: float, source: Actor) -> void:
	damage = hit_damage
	source_actor = source
