extends Component
class_name AimingComponent

signal aim_ended
signal aim_cancelled(aim_owner: Component)
## Presentation may synchronize a moving grip before its world position is read.
signal launch_position_requested

## Pass as default_angle_degrees to use AimingConfig.default_angle_degrees.
const CONFIG_DEFAULT_ANGLE := NAN

@export var config: AimingConfig

var _input: InputComponent
var _facing: FacingComponent
var _owner: Component
var _angle: float = 5.0
var _elapsed: float = 0.0
var _launch_origin: Node2D
var _remembered_angle: float = 0.0
var _remembered_timer: float = 0.0
var _remembered_origin: Vector2 = Vector2.ZERO
var _has_remembered_angle: bool = false


func on_initialize() -> void:
	_input = actor.get_component(InputComponent) as InputComponent
	_facing = actor.get_component(FacingComponent) as FacingComponent
	if (config == null or _input == null or not _input.is_enabled
		or _facing == null or not _facing.is_enabled):
		push_error("AimingComponent requires config, enabled input and facing")
		disable()
		return
	if (config.default_angle_degrees < -90.0 or config.default_angle_degrees > 90.0
		or config.angular_speed_degrees <= 0.0 or config.mouse_degrees_per_pixel <= 0.0
		or config.hold_delay < 0.0 or config.angle_memory_duration < 0.0
		or config.angle_memory_move_tolerance < 0.0):
		push_error("AimingComponent has invalid config")
		disable()


func _ready() -> void:
	process_priority = -80


## Begins a session. default_angle_degrees overrides the config value for owners
## that start from a different angle, such as the bow and the crossbow.
func begin_aim(aim_owner: Component, default_angle_degrees: float = CONFIG_DEFAULT_ANGLE) -> bool:
	if not is_enabled or aim_owner == null or not aim_owner.is_enabled or aim_owner.actor != actor or is_aiming():
		return false
	_owner = aim_owner
	_launch_origin = null
	var starting_angle := (
		config.default_angle_degrees
		if is_nan(default_angle_degrees)
		else default_angle_degrees
	)
	_angle = _remembered_angle if has_remembered_angle() else starting_angle
	_elapsed = 0.0
	_input.consume_aim_mouse_motion()
	return true


## shot_fired records the released angle for the following sessions. Cancelled
## preparations keep the previous memory untouched.
func end_aim(aim_owner: Component, shot_fired: bool = false) -> void:
	if _owner != aim_owner:
		return
	if shot_fired:
		_remember_angle()
	_owner = null
	_launch_origin = null
	aim_ended.emit()


func cancel_aim() -> void:
	if not is_aiming():
		return
	var previous := _owner
	end_aim(previous)
	aim_cancelled.emit(previous)


func is_aiming() -> bool:
	return is_instance_valid(_owner)


func is_indicator_visible() -> bool:
	return is_enabled and is_aiming() and _elapsed >= config.hold_delay


func has_remembered_angle() -> bool:
	return _has_remembered_angle and _remembered_timer > 0.0


func get_remembered_angle() -> float:
	return _remembered_angle


func get_remembered_time_left() -> float:
	return _remembered_timer if _has_remembered_angle else 0.0


func clear_remembered_angle() -> void:
	_has_remembered_angle = false
	_remembered_timer = 0.0


func _remember_angle() -> void:
	if config.angle_memory_duration <= 0.0:
		return
	_remembered_angle = _angle
	_remembered_timer = config.angle_memory_duration
	_remembered_origin = actor.global_position
	_has_remembered_angle = true


func _update_angle_memory(delta: float) -> void:
	if not _has_remembered_angle:
		return
	var tolerance := config.angle_memory_move_tolerance
	if actor.global_position.distance_squared_to(_remembered_origin) > tolerance * tolerance:
		clear_remembered_angle()
		return
	_remembered_timer = maxf(_remembered_timer - delta, 0.0)
	if _remembered_timer == 0.0:
		_has_remembered_angle = false


func get_direction() -> Vector2:
	var radians := deg_to_rad(_angle)
	return Vector2(cos(radians) * float(_facing.get_direction()), -sin(radians))


func get_launch_position() -> Vector2:
	launch_position_requested.emit()
	if is_aiming() and is_instance_valid(_launch_origin):
		return _launch_origin.global_position
	return actor.global_position + config.launch_offset


func set_launch_origin(aim_owner: Component, origin: Node2D) -> void:
	if aim_owner == _owner and is_aiming():
		_launch_origin = origin


func get_locomotion_blocks() -> int:
	if not is_aiming():
		return LocomotionConstraint.Block.NONE
	return (LocomotionConstraint.Block.HORIZONTAL | LocomotionConstraint.Block.JUMP
		| LocomotionConstraint.Block.DODGE)


func _process(delta: float) -> void:
	var mouse_motion := _input.consume_aim_mouse_motion()
	_update_angle_memory(delta)
	if not is_aiming():
		return
	var previous_elapsed := _elapsed
	_elapsed += delta
	if not is_indicator_visible():
		return
	var active_delta := _elapsed - maxf(previous_elapsed, config.hold_delay)
	_angle = clampf(_angle - _input.get_vertical_axis() * config.angular_speed_degrees
		* active_delta - mouse_motion * config.mouse_degrees_per_pixel, -90.0, 90.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_aim()


func disable() -> void:
	cancel_aim()
	super.disable()
