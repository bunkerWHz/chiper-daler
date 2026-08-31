extends Component
class_name RestComponent

const LOCOMOTION_CONSTRAINT := preload(
	"res://features/movement/LocomotionConstraint.gd"
)
const BEHAVIOR_GATE := preload(
	"res://features/state/ExclusiveBehaviorGate.gd"
)

signal rest_started
signal rest_finished

@export var config: RestConfig

var _health: HealthComponent
var _status_effects: StatusEffectComponent
var _flask_charges: FlaskChargesComponent
var _timer: float = 0.0


func on_initialize() -> void:
	if config == null or config.duration <= 0.0:
		push_error("RestComponent requires a valid RestConfig")
		disable()
		return

	_health = actor.get_component(HealthComponent) as HealthComponent
	if _health == null or not _health.is_enabled:
		push_error("RestComponent requires an enabled HealthComponent")
		disable()
		return

	_status_effects = (
		actor.get_component(StatusEffectComponent) as StatusEffectComponent
	)
	_flask_charges = (
		actor.get_component(FlaskChargesComponent) as FlaskChargesComponent
	)


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return

	_timer = maxf(_timer - delta, 0.0)
	if _timer == 0.0:
		rest_finished.emit()


func start_rest() -> bool:
	if (
		not is_enabled
		or is_resting()
		or _health == null
		or _health.is_dead()
		or BEHAVIOR_GATE.is_blocked(actor, self)
	):
		return false

	_timer = config.duration
	_health.heal(_health.get_max_health())
	if _status_effects != null and _status_effects.is_enabled:
		_status_effects.clear_debuffs()
	if _flask_charges != null and _flask_charges.is_enabled:
		_flask_charges.refill_all()
	rest_started.emit()
	return true


func is_resting() -> bool:
	return _timer > 0.0


func is_exclusive_behavior_active() -> bool:
	return is_resting()


func get_locomotion_blocks() -> int:
	if not is_resting():
		return LOCOMOTION_CONSTRAINT.Block.NONE
	return (
		LOCOMOTION_CONSTRAINT.Block.HORIZONTAL
		| LOCOMOTION_CONSTRAINT.Block.JUMP
		| LOCOMOTION_CONSTRAINT.Block.DODGE
	)


func disable() -> void:
	var was_resting := is_resting()
	_timer = 0.0
	if was_resting:
		rest_finished.emit()
	super.disable()
