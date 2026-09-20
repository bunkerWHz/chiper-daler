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
		or config.max_level < 2
		or config.max_level > ProgressionConfig.ABSOLUTE_MAX_LEVEL
		or config.level_up_state_duration <= 0.0
	):
		push_error("ProgressionComponent requires a valid ProgressionConfig")
		disable()


func _process(delta: float) -> void:
	_level_up_timer = maxf(_level_up_timer - delta, 0.0)


func gain_experience(amount: int) -> int:
	if not is_enabled or amount <= 0 or is_max_level():
		return 0

	var previous_level := _level
	_experience += amount

	while _level < get_max_level() and _experience >= get_experience_required():
		_experience -= get_experience_required()
		_level += 1

	if is_max_level():
		# Experience has no consumer past the cap; keeping it would only
		# make the interface promise a level that can no longer arrive.
		_experience = 0

	if _level > previous_level:
		_level_up_timer = config.level_up_state_duration
		leveled_up.emit(previous_level, _level)

	experience_changed.emit(_experience, get_experience_required())
	return _level - previous_level


func get_level() -> int:
	return _level


func get_max_level() -> int:
	return config.max_level if config != null else 1


func is_max_level() -> bool:
	return _level >= get_max_level()


func get_experience() -> int:
	return _experience


## Experience still needed to reach the next level. Zero at the level cap,
## where no further purchase is possible.
func get_experience_required() -> int:
	if is_max_level():
		return 0
	return maxi(_requirement_for_level(_level), 1)


## Total experience that still separates the current state from the level cap.
## Used to refuse an exchange that would pay for levels that cannot happen.
func get_experience_to_max_level() -> int:
	if is_max_level():
		return 0

	var remaining := 0
	var level := _level
	var experience := _experience
	while level < get_max_level():
		remaining += maxi(_requirement_for_level(level) - experience, 0)
		experience = 0
		level += 1
	return remaining


func is_leveling_up() -> bool:
	return _level_up_timer > 0.0


func capture_runtime_state() -> Variant:
	return {
		"level": _level,
		"experience": _experience,
	}


func restore_runtime_state(state: Variant) -> void:
	if not state is Dictionary:
		return

	_level = clampi(int(state.get("level", _level)), 1, get_max_level())
	_experience = 0
	if not is_max_level():
		_experience = clampi(
			int(state.get("experience", _experience)),
			0,
			get_experience_required() - 1
		)
	_level_up_timer = 0.0
	experience_changed.emit(_experience, get_experience_required())


func disable() -> void:
	_level_up_timer = 0.0
	super.disable()


func _requirement_for_level(level: int) -> int:
	return roundi(
		config.initial_experience_required
		* pow(config.requirement_growth, level - 1)
	)
