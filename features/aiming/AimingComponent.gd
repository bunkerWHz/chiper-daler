extends Component
class_name AimingComponent

signal aim_ended
signal aim_cancelled(aim_owner: Component)
## Presentation may synchronize a moving grip before its world position is read.
signal launch_position_requested

@export var config: AimingConfig

var _input: InputComponent
var _facing: FacingComponent
var _owner: Component
var _angle: float = 15.0
var _elapsed: float = 0.0
var _launch_origin: Node2D


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
		or config.hold_delay < 0.0):
		push_error("AimingComponent has invalid config")
		disable()


func _ready() -> void:
	process_priority = -80


func begin_aim(aim_owner: Component) -> bool:
	if not is_enabled or aim_owner == null or not aim_owner.is_enabled or aim_owner.actor != actor or is_aiming():
		return false
	_owner = aim_owner
	_launch_origin = null
	_angle = config.default_angle_degrees
	_elapsed = 0.0
	_input.consume_aim_mouse_motion()
	return true


func end_aim(aim_owner: Component) -> void:
	if _owner != aim_owner:
		return
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
