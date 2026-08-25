extends Resource
class_name EnemyAttackConfig

@export_range(1.0, 200.0, 1.0) var attack_range: float = 26.0
@export_range(0.0, 2.0, 0.01) var windup_duration: float = 0.25
@export var telegraph_modulate: Color = Color(1.0, 0.75, 0.2, 1.0)
@export var stop_movement_in_range: bool = true
