extends Component
class_name EnemyMovementComponent

@export var config: EnemyMovementConfig

var _body_component: CharacterBodyComponent
var _move_direction: float = 0.0


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
	velocity.x = _move_direction * config.move_speed

	if not _body_component.is_on_floor():
		velocity.y += config.gravity * delta

	_body_component.set_velocity(velocity)
	_body_component.move_and_slide()


func set_move_direction(direction: float) -> void:
	_move_direction = clampf(direction, -1.0, 1.0)


func stop() -> void:
	_move_direction = 0.0


func get_move_direction() -> float:
	return _move_direction
