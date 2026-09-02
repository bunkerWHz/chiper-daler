extends Resource
class_name EnemyVisualConfig

@export_dir var animation_root: String
@export_range(1.0, 60.0, 1.0) var frames_per_second: float = 18.0
@export var visual_scale: Vector2 = Vector2(0.18, 0.18)
@export var visual_offset: Vector2 = Vector2.ZERO
@export var art_faces_left: bool = false
@export var idle_folder: StringName = &"Idle"
@export var move_folder: StringName = &"Walking"
@export var airborne_folder: StringName = &"Jump"
@export var attack_folder: StringName = &"Attack"
@export var death_folder: StringName = &"Dying"
