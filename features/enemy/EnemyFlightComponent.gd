extends Component
class_name EnemyFlightComponent

@export var config: EnemyFlightConfig

var _body_component: CharacterBodyComponent
var _home_position: Vector2
var _patrol_direction: float = -1.0
var _patrol_time: float = 0.0
var _chase_target: Vector2
var _has_chase_target: bool = false
var _is_stopped: bool = false


func on_initialize() -> void:
	if config == null:
		push_error("EnemyFlightComponent requires EnemyFlightConfig")
		disable()
		return

	_body_component = actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	if _body_component == null or not _body_component.is_enabled:
		push_error("EnemyFlightComponent requires CharacterBodyComponent")
		disable()
		return

	_home_position = actor.global_position
	_patrol_direction = signf(config.initial_direction.x)
	if is_zero_approx(_patrol_direction):
		_patrol_direction = -1.0


func _physics_process(delta: float) -> void:
	_patrol_time += delta
	var desired_velocity := Vector2.ZERO

	if not _is_stopped:
		var destination := _get_destination()
		var offset := destination - actor.global_position
		if offset.length() > config.target_stopping_distance:
			desired_velocity = offset.normalized() * config.move_speed

	var velocity := _body_component.get_velocity()
	velocity = velocity.move_toward(desired_velocity, config.acceleration * delta)
	_body_component.set_velocity(velocity)
	_body_component.move_and_slide()


func set_chase_target(world_position: Vector2) -> void:
	_chase_target = world_position
	_has_chase_target = true
	_is_stopped = false


func clear_chase_target() -> void:
	_has_chase_target = false


func stop() -> bool:
	_is_stopped = true
	return true


func capture_move_intent() -> Variant:
	return {
		"has_chase_target": _has_chase_target,
		"chase_target": _chase_target,
		"is_stopped": _is_stopped,
	}


func restore_move_intent(intent: Variant) -> void:
	if not intent is Dictionary:
		return
	_has_chase_target = bool(intent.get("has_chase_target", false))
	_chase_target = intent.get("chase_target", Vector2.ZERO)
	_is_stopped = bool(intent.get("is_stopped", false))


func get_facing_direction() -> float:
	var velocity := _body_component.get_velocity()
	return signf(velocity.x) if not is_zero_approx(velocity.x) else _patrol_direction


func _get_destination() -> Vector2:
	if _has_chase_target:
		return _chase_target

	if config.patrol_distance > 0.0:
		var distance_from_home := actor.global_position.x - _home_position.x
		if absf(distance_from_home) >= config.patrol_distance:
			_patrol_direction = -signf(distance_from_home)

	var patrol_y := sin(_patrol_time * config.patrol_vertical_frequency * TAU)
	return _home_position + Vector2(
		_patrol_direction * config.patrol_distance,
		patrol_y * config.patrol_vertical_amplitude
	)
