extends Component
class_name EnemyMovementComponent

@export var config: EnemyMovementConfig

var _body_component: CharacterBodyComponent
var _move_direction: float = 0.0
var _is_move_direction_locked: bool = false
var _committed_jump_speed: float = -1.0


func on_initialize() -> void:
	if config == null:
		push_error("EnemyMovementComponent requires EnemyMovementConfig")
		disable()
		return

	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if _body_component == null or not _body_component.is_enabled:
		push_error(
			"EnemyMovementComponent requires an enabled CharacterBodyComponent"
		)
		disable()
		return

	set_move_direction(config.initial_direction)


func _physics_process(delta: float) -> void:
	var velocity := _body_component.get_velocity()
	var horizontal_speed := config.move_speed

	if _committed_jump_speed >= 0.0:
		horizontal_speed = _committed_jump_speed

	velocity.x = _move_direction * horizontal_speed

	if not _body_component.is_on_floor():
		velocity.y += config.gravity * delta

	_body_component.set_velocity(velocity)
	_body_component.move_and_slide()


func set_move_direction(direction: float) -> bool:
	if _is_move_direction_locked:
		return false

	_move_direction = clampf(direction, -1.0, 1.0)
	return true


func stop() -> bool:
	return set_move_direction(0.0)


func lock_move_direction() -> void:
	_is_move_direction_locked = true


func unlock_move_direction() -> void:
	_is_move_direction_locked = false
	_committed_jump_speed = -1.0


func is_move_direction_locked() -> bool:
	return _is_move_direction_locked


func jump(jump_velocity: float, horizontal_speed: float = -1.0) -> bool:
	if (
		not is_enabled
		or jump_velocity <= 0.0
		or not _body_component.is_on_floor()
	):
		return false

	var velocity := _body_component.get_velocity()
	velocity.y = -jump_velocity
	_committed_jump_speed = (
		clampf(horizontal_speed, 0.0, config.move_speed)
		if horizontal_speed >= 0.0
		else config.move_speed
	)
	_body_component.set_velocity(velocity)
	return true


func get_move_direction() -> float:
	return _move_direction


func set_chase_target(world_position: Vector2) -> void:
	set_move_direction(signf(world_position.x - actor.global_position.x))


func clear_chase_target() -> void:
	pass


func capture_move_intent() -> Variant:
	return _move_direction


func restore_move_intent(intent: Variant) -> void:
	set_move_direction(float(intent))


func get_facing_direction() -> float:
	return _move_direction
