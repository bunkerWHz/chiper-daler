extends Resource
class_name MovementConfig

@export var move_speed: float = 200.0
@export var gravity: float = 1200.0

@export var jump_velocity: float = 450.0
@export var air_jump_velocity: float = 450.0
@export_range(1, 5, 1) var max_jump_count: int = 2
@export var jump_cut_multiplier: float = 0.5
@export var jump_buffer_time: float = 0.2
@export var coyote_time: float = 0.2

@export var acceleration_mode: AccelerationMode = AccelerationMode.SMOOTH
@export var acceleration: float = 1200.0
@export var deceleration: float = 1500.0

enum AccelerationMode {
	INSTANT,
	SMOOTH
}
