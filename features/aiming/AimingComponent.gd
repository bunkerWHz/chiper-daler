extends Component
class_name AimingComponent

signal aim_ended
signal aim_cancelled(owner: Component)

@export var config: AimingConfig

var _input: InputComponent
var _facing: FacingComponent
var _owner: Component
var _angle: float = 15.0
var _elapsed: float = 0.0


func on_initialize() -> void:
	_input = actor.get_component(InputComponent) as InputComponent
	_facing = actor.get_component(FacingComponent) as FacingComponent
	if (config == null or _input == null or not _input.is_enabled
		or _facing == null or not _facing.is_enabled):
		push_error("AimingComponent requires config, enabled input and facing")
		disable()
		return
	if (config.default_angle_degrees < 0.0 or config.default_angle_degrees > 90.0
		or config.angular_speed_degrees <= 0.0 or config.mouse_degrees_per_pixel <= 0.0
		or config.hold_delay < 0.0):
		push_error("AimingComponent has invalid config")
		disable()


func _ready() -> void:
	process_priority = -80


func begin_aim(owner: Component) -> bool:
	if not is_enabled or owner == null or not owner.is_enabled or owner.actor != actor or is_aiming():
		return false
	_owner = owner
	_angle = config.default_angle_degrees
	_elapsed = 0.0
	_input.consume_aim_mouse_motion()
	return true


func end_aim(owner: Component) -> void:
	if _owner != owner:
		return
	_owner = null
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
	return actor.global_position + config.launch_offset


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
		* active_delta - mouse_motion * config.mouse_degrees_per_pixel, 0.0, 90.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_aim()


func disable() -> void:
	cancel_aim()
	super.disable()
