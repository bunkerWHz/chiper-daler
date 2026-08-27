extends Component
class_name RestComponent

signal rest_started
signal rest_finished

@export var config: RestConfig

var _health: HealthComponent
var _status_effects: StatusEffectComponent
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


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return

	_timer = maxf(_timer - delta, 0.0)
	if _timer == 0.0:
		rest_finished.emit()


func start_rest() -> bool:
	if not is_enabled or _health == null or _health.is_dead():
		return false

	_timer = config.duration
	_health.heal(_health.get_max_health())
	if _status_effects != null and _status_effects.is_enabled:
		_status_effects.clear_debuffs()
	rest_started.emit()
	return true


func is_resting() -> bool:
	return _timer > 0.0


func disable() -> void:
	_timer = 0.0
	super.disable()
