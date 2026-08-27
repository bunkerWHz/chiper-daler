extends Component
class_name HealthComponent

signal health_changed(previous_health: float, current_health: float)
signal damaged(amount: float, current_health: float)
signal died

@export var config: HealthConfig

var _current_health: float = 0.0


func on_initialize() -> void:
	if config == null:
		push_error("HealthComponent requires HealthConfig")
		disable()
		return

	if config.max_health <= 0.0:
		push_error("HealthConfig max_health must be greater than zero")
		disable()
		return

	_current_health = config.max_health


func get_current_health() -> float:
	return _current_health


func get_max_health() -> float:
	return config.max_health


func get_health_ratio() -> float:
	return _current_health / config.max_health


func is_alive() -> bool:
	return _current_health > 0.0


func is_dead() -> bool:
	return not is_alive()


func take_damage(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0

	var previous_health := _current_health
	_current_health = maxf(_current_health - amount, 0.0)
	var applied_damage := previous_health - _current_health

	health_changed.emit(previous_health, _current_health)
	damaged.emit(applied_damage, _current_health)

	if is_dead():
		died.emit()

	return applied_damage


func heal(amount: float) -> float:
	if amount <= 0.0 or not is_alive():
		return 0.0

	var previous_health := _current_health
	_current_health = minf(_current_health + amount, config.max_health)
	var restored_health := _current_health - previous_health

	if restored_health > 0.0:
		health_changed.emit(previous_health, _current_health)

	return restored_health
