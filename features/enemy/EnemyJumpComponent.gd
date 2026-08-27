extends Component
class_name EnemyJumpComponent

signal jump_started(target: Actor)
signal jump_landed(target: Actor)
signal jump_cancelled(target: Actor)

const TRAJECTORY_CALCULATOR := preload(
	"res://features/movement/JumpTrajectoryCalculator.gd"
)

@export var config: EnemyJumpConfig

var _body_component: CharacterBodyComponent
var _movement_component: EnemyMovementComponent
var _chase_component: EnemyChaseComponent
var _ground_sensor: EnemyGroundSensorComponent
var _cooldown_timer: float = 0.0
var _is_jumping: bool = false
var _has_left_ground: bool = false
var _jump_target: Actor
var _jump_destination: Vector2


func on_initialize() -> void:
	if config == null:
		push_error("EnemyJumpComponent requires EnemyJumpConfig")
		disable()
		return

	if (
		config.jump_velocity <= 0.0
		or config.cooldown < 0.0
		or config.landing_probe_depth <= 0.0
	):
		push_error("EnemyJumpComponent has an invalid config")
		disable()
		return

	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)
	_movement_component = (
		actor.get_component(EnemyMovementComponent)
		as EnemyMovementComponent
	)
	_chase_component = (
		actor.get_component(EnemyChaseComponent)
		as EnemyChaseComponent
	)
	_ground_sensor = (
		actor.get_component(EnemyGroundSensorComponent)
		as EnemyGroundSensorComponent
	)

	if (
		_body_component == null
		or not _body_component.is_enabled
		or _movement_component == null
		or not _movement_component.is_enabled
		or _chase_component == null
		or not _chase_component.is_enabled
		or _ground_sensor == null
		or not _ground_sensor.is_enabled
	):
		push_error("EnemyJumpComponent requires movement, chase, and ground sensor")
		disable()


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_update_jump_commitment()

	if _cooldown_timer > 0.0 or not _ground_sensor.is_grounded():
		return

	var target := _chase_component.get_target()

	if target == null:
		return

	var offset := target.actor.global_position - actor.global_position
	var direction := signf(offset.x)

	if is_zero_approx(direction) or not can_reach_offset(offset):
		return

	var ground_is_unsafe := (
		config.jump_at_unsafe_ground
		and not _ground_sensor.is_direction_safe(direction)
	)

	if not should_attempt_jump(
		offset,
		_is_target_grounded(target),
		ground_is_unsafe
	):
		return

	if (
		config.require_landing_surface
		and not _has_landing_surface(target)
	):
		return

	if not _movement_component.set_move_direction(direction):
		return

	_movement_component.lock_move_direction()

	var jump_speed := minf(
		get_required_horizontal_speed(offset),
		_movement_component.config.move_speed
	)

	if _movement_component.jump(config.jump_velocity, jump_speed):
		_is_jumping = true
		_has_left_ground = false
		_jump_target = target.actor
		_jump_destination = target.actor.global_position
		_cooldown_timer = config.cooldown
		jump_started.emit(target.actor)
	else:
		_movement_component.unlock_move_direction()


func can_reach_offset(offset: Vector2) -> bool:
	if _movement_component == null or _movement_component.config == null:
		return false

	if not TRAJECTORY_CALCULATOR.can_reach_height(
		_movement_component.config.gravity,
		config.jump_velocity,
		offset.y
	):
		return false

	var horizontal_reach: float = (
		TRAJECTORY_CALCULATOR.get_horizontal_reach_at_height(
			_movement_component.config.move_speed,
			_movement_component.config.gravity,
			config.jump_velocity,
			offset.y
		)
	)
	return absf(offset.x) <= horizontal_reach + config.landing_tolerance


func is_on_cooldown() -> bool:
	return _cooldown_timer > 0.0


func is_jumping() -> bool:
	return _is_jumping


func get_jump_destination() -> Vector2:
	return _jump_destination


func get_required_horizontal_speed(offset: Vector2) -> float:
	if _movement_component == null or _movement_component.config == null:
		return 0.0

	var flight_time: float = TRAJECTORY_CALCULATOR.get_flight_time_at_height(
		_movement_component.config.gravity,
		config.jump_velocity,
		offset.y
	)

	if flight_time <= 0.0:
		return 0.0

	return absf(offset.x) / flight_time


func should_attempt_jump(
	offset: Vector2,
	target_is_grounded: bool,
	ground_is_unsafe: bool
) -> bool:
	if not target_is_grounded:
		return false

	var target_is_above := offset.y <= -config.min_upward_offset
	return target_is_above or (
		config.jump_at_unsafe_ground and ground_is_unsafe
	)


func _is_target_grounded(target: HurtboxComponent) -> bool:
	var target_body_component := (
		target.actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	return (
		target_body_component != null
		and target_body_component.is_enabled
		and target_body_component.is_on_floor()
	)


func _has_landing_surface(target: HurtboxComponent) -> bool:
	var excluded_body := RID()
	var target_body_component := (
		target.actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if target_body_component != null and target_body_component.is_enabled:
		excluded_body = target_body_component.get_body().get_rid()

	return _ground_sensor.has_floor_at(
		target.actor.global_position,
		config.landing_probe_up,
		config.landing_probe_depth,
		excluded_body
	)


func _update_jump_commitment() -> void:
	if not _is_jumping:
		return

	if not _ground_sensor.is_grounded():
		_has_left_ground = true
		return

	if _has_left_ground:
		var landed_target := _jump_target
		_is_jumping = false
		_has_left_ground = false
		_jump_target = null
		_jump_destination = Vector2.ZERO
		_movement_component.unlock_move_direction()
		jump_landed.emit(landed_target)


func disable() -> void:
	var cancelled_target := _jump_target
	var was_jumping := _is_jumping
	_is_jumping = false
	_has_left_ground = false
	_jump_target = null
	_jump_destination = Vector2.ZERO

	if _movement_component != null:
		_movement_component.unlock_move_direction()

	super.disable()

	if was_jumping:
		jump_cancelled.emit(cancelled_target)
