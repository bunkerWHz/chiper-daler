extends Resource
class_name CameraConfig

@export_category("Smoothing")
@export var position_smoothing_enabled: bool = true
@export_range(0.1, 30.0, 0.1) var position_smoothing_speed: float = 8.0

@export_category("Zoom")
@export var zoom: Vector2 = Vector2.ONE

@export_category("Limits")
@export var limit_left: int = 0
@export var limit_top: int = 0
@export var limit_right: int = 2000
@export var limit_bottom: int = 1000
