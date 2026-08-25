extends Resource
class_name DamageNumberConfig

@export_range(0.1, 3.0, 0.05) var duration: float = 0.65
@export_range(1.0, 100.0, 1.0) var rise_distance: float = 24.0
@export var spawn_offset: Vector2 = Vector2(0.0, -24.0)
@export var color: Color = Color(1.0, 0.82, 0.22, 1.0)
@export_range(8, 48, 1) var font_size: int = 14
