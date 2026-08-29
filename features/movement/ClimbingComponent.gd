extends Component
class_name ClimbingComponent

const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal climbing_started(climbable: ClimbableArea)
signal climbing_finished

const CLIMB_PROCESS_PRIORITY := -40

@export var config: ClimbingConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _facing_component: FacingComponent
var _dodge_component: Component
var _available_climbables: Array[ClimbableArea] = []
var _current_climbable: ClimbableArea
var _is_climbing: bool = false
var _vertical_direction: float = 0.0
var _exit_control_timer: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("ClimbingComponent requires ClimbingConfig")
		disable()
		return

	if (
		config.climb_speed <= 0.0
		or config.exit_jump_horizontal_velocity <= 0.0
		or config.exit_jump_vertical_velocity <= 0.0
		or config.exit_control_lock_time < 0.0
	):
		push_error("ClimbingComponent has an invalid config")
		disable()
		return

	_input_component = actor.get_component(InputComponent) as InputComponent
	_body_component = (
		actor.get_component(CharacterBodyComponent)
		as CharacterBodyComponent
	)
	_facing_component = (
		actor.get_component(FacingComponent) as FacingComponent
	)
	_dodge_component = actor.get_component(DodgeComponent)

	if _input_component == null or not _input_component.is_enabled:
		push_error("ClimbingComponent requires an enabled InputComponent")
		disable()
		return

	if _body_component == null or not _body_component.is_enabled:
		push_error("ClimbingComponent requires an enabled CharacterBodyComponent")
		disable()
		return

	if _facing_component == null or not _facing_component.is_enabled:
		push_error("ClimbingComponent requires an enabled FacingComponent")
		disable()


func _ready() -> void:
	process_physics_priority = CLIMB_PROCESS_PRIORITY


func _physics_process(delta: float) -> void:
	_exit_control_timer = maxf(_exit_control_timer - delta, 0.0)
	_remove_invalid_climbables()

	if (
		_is_climbing
		and _dodge_component != null
		and _dodge_component.is_enabled
		and bool(_dodge_component.call("is_dodging"))
	):
		stop_climbing()
		return

	if _is_climbing:
		if not is_instance_valid(_current_climbable):
			stop_climbing()
			return

		if _input_component.consume_jump_pressed():
			exit_with_jump()
			return

		_vertical_direction = _input_component.get_vertical_axis()
		return

	if (
		not _available_climbables.is_empty()
		and not is_zero_approx(_input_component.get_vertical_axis())
	):
		start_climbing(_available_climbables.back())


func enter_climbable(climbable: ClimbableArea) -> void:
	if climbable == null or _available_climbables.has(climbable):
		return

	_available_climbables.append(climbable)


func exit_climbable(climbable: ClimbableArea) -> void:
	_available_climbables.erase(climbable)

	if climbable == _current_climbable:
		stop_climbing()


func start_climbing(climbable: ClimbableArea) -> bool:
	if not can_start_climbing() or not _available_climbables.has(climbable):
		return false

	_is_climbing = true
	_current_climbable = climbable
	_vertical_direction = _input_component.get_vertical_axis()
	_body_component.set_velocity(Vector2.ZERO)
	climbing_started.emit(climbable)
	return true


func stop_climbing() -> void:
	if not _is_climbing:
		return

	_is_climbing = false
	_current_climbable = null
	_vertical_direction = 0.0
	climbing_finished.emit()


func exit_with_jump() -> bool:
	if not _is_climbing:
		return false

	var direction := float(_facing_component.get_direction())
	stop_climbing()
	_body_component.set_velocity(Vector2(
		direction * config.exit_jump_horizontal_velocity,
		-config.exit_jump_vertical_velocity
	))
	_exit_control_timer = config.exit_control_lock_time
	return true


func can_start_climbing() -> bool:
	if (
		not is_enabled
		or _is_climbing
		or _exit_control_timer > 0.0
		or _available_climbables.is_empty()
		or BEHAVIOR_GATE.is_blocked(actor, self)
	):
		return false

	return not (
		_dodge_component != null
		and _dodge_component.is_enabled
		and bool(_dodge_component.call("is_dodging"))
	)


func apply_velocity() -> void:
	if not _is_climbing:
		return

	_body_component.set_velocity(Vector2(
		0.0,
		_vertical_direction * config.climb_speed
	))


func is_climbing() -> bool:
	return _is_climbing


func is_exclusive_behavior_active() -> bool:
	return is_climbing()


func is_exiting_climb() -> bool:
	return _exit_control_timer > 0.0


func get_vertical_direction() -> float:
	return _vertical_direction


func disable() -> void:
	stop_climbing()
	_available_climbables.clear()
	_exit_control_timer = 0.0
	super.disable()


func _remove_invalid_climbables() -> void:
	for index in range(_available_climbables.size() - 1, -1, -1):
		if not is_instance_valid(_available_climbables[index]):
			_available_climbables.remove_at(index)
