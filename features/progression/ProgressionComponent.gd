extends Component
class_name ProgressionComponent

signal experience_changed(current: int, required: int)
signal leveled_up(previous_level: int, current_level: int)

@export var config: ProgressionConfig

var _level: int = 1
var _experience: int = 0
var _level_up_timer: float = 0.0


func on_initialize() -> void:
	if (
		config == null
		or config.initial_experience_required <= 0
		or config.requirement_growth < 1.0
		or config.level_up_state_duration <= 0.0
	):
		push_error("ProgressionComponent requires a valid ProgressionConfig")
		disable()


func _process(delta: float) -> void:
	_level_up_timer = maxf(_level_up_timer - delta, 0.0)


func gain_experience(amount: int) -> int:
	if not is_enabled or amount <= 0:
		return 0

	var previous_level := _level
	_experience += amount

	while _experience >= get_experience_required():
		_experience -= get_experience_required()
		_level += 1

	if _level > previous_level:
		_level_up_timer = config.level_up_state_duration
		leveled_up.emit(previous_level, _level)

	experience_changed.emit(_experience, get_experience_required())
	return _level - previous_level


func get_level() -> int:
	return _level


func get_experience() -> int:
	return _experience


func get_experience_required() -> int:
	return maxi(
		roundi(
			config.initial_experience_required
			* pow(config.requirement_growth, _level - 1)
		),
		1
	)


func is_leveling_up() -> bool:
	return _level_up_timer > 0.0


func disable() -> void:
	_level_up_timer = 0.0
	super.disable()
