extends Component
class_name KnockbackComponent

signal knockback_started(velocity: Vector2)
signal knockback_finished

@export var config: KnockbackConfig

var _body_component: CharacterBodyComponent
var _timer: float = 0.0
var _suspended_movement_components: Array[Component] = []


func on_initialize() -> void:
	if config == null:
		push_error("KnockbackComponent requires KnockbackConfig")
		disable()
		return

	if config.duration <= 0.0:
		push_error("KnockbackConfig duration must be greater than zero")
		disable()
		return

	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)

	if _body_component == null or not _body_component.is_enabled:
		push_error("KnockbackComponent requires an enabled CharacterBodyComponent")
		disable()


func _physics_process(delta: float) -> void:
	if _timer <= 0.0:
		return

	var velocity := _body_component.get_velocity()
	velocity.x = move_toward(
		velocity.x,
		0.0,
		config.horizontal_drag * delta
	)

	if not _body_component.is_on_floor():
		velocity.y += config.gravity * delta

	_body_component.set_velocity(velocity)
	_body_component.move_and_slide()
	_timer = maxf(_timer - delta, 0.0)

	if _timer == 0.0:
		_finish_knockback()


func apply_hit(hit: HitData) -> bool:
	if (
		not is_enabled
		or hit == null
		or hit.knockback_velocity.is_zero_approx()
	):
		return false

	_suspend_movement()
	_timer = config.duration
	_body_component.set_velocity(hit.knockback_velocity)
	knockback_started.emit(hit.knockback_velocity)
	return true


func is_knocked_back() -> bool:
	return _timer > 0.0


func disable() -> void:
	_timer = 0.0
	_suspended_movement_components.clear()
	super.disable()


func _suspend_movement() -> void:
	if not _suspended_movement_components.is_empty():
		return

	var player_movement := actor.get_component(MovementComponent)
	var enemy_movement := actor.get_component(EnemyMovementComponent)

	for movement: Component in [player_movement, enemy_movement]:
		if movement != null and movement.is_enabled:
			movement.disable()
			_suspended_movement_components.append(movement)


func _finish_knockback() -> void:
	for movement: Component in _suspended_movement_components:
		if is_instance_valid(movement):
			movement.enable()

	_suspended_movement_components.clear()
	knockback_finished.emit()
