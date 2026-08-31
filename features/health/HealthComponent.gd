extends Component
class_name HealthComponent

signal health_changed(previous_health: float, current_health: float)
signal damaged(amount: float, current_health: float)
signal died

@export var config: HealthConfig

var _current_health: float = 0.0
var _max_health: float = 1.0
var _attributes: CharacterAttributesComponent


func on_initialize() -> void:
	if config == null:
		push_error("HealthComponent requires HealthConfig")
		disable()
		return

	if config.max_health <= 0.0:
		push_error("HealthConfig max_health must be greater than zero")
		disable()
		return

	_attributes = (
		actor.get_component(CharacterAttributesComponent)
		as CharacterAttributesComponent
	)
	if _attributes != null and _attributes.is_enabled:
		if not _attributes.attributes_changed.is_connected(
			_on_attributes_changed
		):
			_attributes.attributes_changed.connect(_on_attributes_changed)
	else:
		_attributes = null
	_max_health = _calculate_max_health()
	_current_health = _max_health


func get_current_health() -> float:
	return _current_health


func get_max_health() -> float:
	return _max_health


func get_health_ratio() -> float:
	return _current_health / _max_health


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
	_current_health = minf(_current_health + amount, _max_health)
	var restored_health := _current_health - previous_health

	if restored_health > 0.0:
		health_changed.emit(previous_health, _current_health)

	return restored_health


func _calculate_max_health() -> float:
	var endurance_bonus := (
		_attributes.get_endurance_health_bonus()
		if _attributes != null
		else 0.0
	)
	return maxf(config.max_health + endurance_bonus, 1.0)


func _on_attributes_changed(
	_strength: int,
	_dexterity: int,
	_intelligence: int,
	_endurance: int,
	_wisdom: int
) -> void:
	var previous_health := _current_health
	var previous_max := _max_health
	_max_health = _calculate_max_health()
	if _current_health > 0.0 and _max_health > previous_max:
		_current_health += _max_health - previous_max
	_current_health = clampf(_current_health, 0.0, _max_health)
	health_changed.emit(previous_health, _current_health)
