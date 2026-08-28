extends Component
class_name DodgeComponent

signal dodge_started(direction: float)
signal dodge_finished

const DODGE_PROCESS_PRIORITY := -50

@export var config: DodgeConfig

var _input_component: InputComponent
var _body_component: CharacterBodyComponent
var _facing_component: FacingComponent
var _invulnerability_component: InvulnerabilityComponent
var _attack_component: AttackComponent
var _guard_component: GuardComponent
var _active_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _direction: float = 1.0
var _air_dodge_available: bool = true


func on_initialize() -> void:
	if config == null:
		push_error("DodgeComponent requires DodgeConfig")
		disable()
		return

	if (
		config.speed <= 0.0
		or config.duration <= 0.0
		or config.cooldown < 0.0
		or config.invulnerability_duration < 0.0
	):
		push_error("DodgeComponent has an invalid config")
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
	_invulnerability_component = (
		actor.get_component(InvulnerabilityComponent)
		as InvulnerabilityComponent
	)
	_attack_component = (
		actor.get_component(AttackComponent) as AttackComponent
	)
	_guard_component = actor.get_component(GuardComponent) as GuardComponent

	if _input_component == null or not _input_component.is_enabled:
		push_error("DodgeComponent requires an enabled InputComponent")
		disable()
		return

	if _body_component == null or not _body_component.is_enabled:
		push_error("DodgeComponent requires an enabled CharacterBodyComponent")
		disable()
		return

	if _facing_component == null or not _facing_component.is_enabled:
		push_error("DodgeComponent requires an enabled FacingComponent")
		disable()
		return

	if (
		_invulnerability_component != null
		and not _invulnerability_component.is_enabled
	):
		_invulnerability_component = null


func _ready() -> void:
	process_physics_priority = DODGE_PROCESS_PRIORITY


func _physics_process(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if _body_component.is_on_floor():
		_air_dodge_available = true

	if _active_timer > 0.0:
		_active_timer = maxf(_active_timer - delta, 0.0)

		if _active_timer == 0.0:
			dodge_finished.emit()

	if _input_component.consume_dodge_pressed():
		try_start_dodge()


func try_start_dodge() -> bool:
	if not can_dodge():
		return false

	var is_air_dodge := not _body_component.is_on_floor()
	var input_direction := _input_component.get_move_axis()
	_direction = (
		signf(input_direction)
		if not is_zero_approx(input_direction)
		else float(_facing_component.get_direction())
	)
	_active_timer = config.duration
	_cooldown_timer = config.cooldown

	if is_air_dodge:
		_air_dodge_available = false

	if (
		_invulnerability_component != null
		and config.invulnerability_duration > 0.0
	):
		_invulnerability_component.activate(
			config.invulnerability_duration
		)

	if _guard_component != null and _guard_component.is_enabled:
		_guard_component.stop_guard()

	dodge_started.emit(_direction)
	return true


func can_dodge() -> bool:
	if not is_enabled or is_dodging() or _cooldown_timer > 0.0:
		return false
	if (
		_guard_component != null
		and _guard_component.is_enabled
		and _guard_component.is_defending()
	):
		return false

	if (
		_attack_component != null
		and _attack_component.is_enabled
		and (
			_attack_component.is_attacking()
			or _attack_component.is_charging_heavy_attack()
		)
	):
		return false

	return (
		_body_component.is_on_floor()
		or (config.allow_air_dodge and _air_dodge_available)
	)


func apply_velocity() -> void:
	if not is_dodging():
		return

	_body_component.set_velocity(Vector2(_direction * config.speed, 0.0))


func is_dodging() -> bool:
	return _active_timer > 0.0


func get_direction() -> float:
	return _direction


func disable() -> void:
	var was_dodging := is_dodging()
	_active_timer = 0.0

	if was_dodging:
		dodge_finished.emit()

	super.disable()
