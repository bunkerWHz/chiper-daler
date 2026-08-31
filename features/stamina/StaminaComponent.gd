extends Component
class_name StaminaComponent

signal stamina_changed(current: float, maximum: float)

@export var config: StaminaConfig

var _stamina: float = 0.0
var _regeneration_delay: float = 0.0


func on_initialize() -> void:
	if config == null or config.max_stamina <= 0.0:
		push_error("StaminaComponent requires a valid StaminaConfig")
		disable()
		return
	_stamina = config.max_stamina
	stamina_changed.emit(_stamina, config.max_stamina)


func _process(delta: float) -> void:
	if _regeneration_delay > 0.0:
		var consumed_delay := minf(_regeneration_delay, delta)
		_regeneration_delay -= consumed_delay
		delta -= consumed_delay
	if delta <= 0.0 or _stamina >= config.max_stamina:
		return
	_set_stamina(_stamina + config.regeneration_per_second * delta)


func spend(amount: float) -> bool:
	if not is_enabled or amount <= 0.0 or _stamina < amount:
		return false
	_set_stamina(_stamina - amount)
	_regeneration_delay = config.regeneration_delay
	return true


func restore(amount: float) -> float:
	if not is_enabled or amount <= 0.0:
		return 0.0
	var previous := _stamina
	_set_stamina(_stamina + amount)
	return _stamina - previous


func get_stamina() -> float:
	return _stamina


func get_max_stamina() -> float:
	return config.max_stamina


func capture_runtime_state() -> Variant:
	return _stamina


func restore_runtime_state(state: Variant) -> void:
	_set_stamina(float(state))


func _set_stamina(value: float) -> void:
	var resolved := clampf(value, 0.0, config.max_stamina)
	if is_equal_approx(resolved, _stamina):
		return
	_stamina = resolved
	stamina_changed.emit(_stamina, config.max_stamina)
