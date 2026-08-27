extends Component
class_name StatusEffectComponent

signal effect_applied(effect: StatusEffect)
signal effect_removed(effect_id: StringName)

var _active_effects: Array[Dictionary] = []


func _process(delta: float) -> void:
	for index in range(_active_effects.size() - 1, -1, -1):
		var entry := _active_effects[index]
		entry["remaining"] = maxf(float(entry["remaining"]) - delta, 0.0)

		if float(entry["remaining"]) == 0.0:
			var effect := entry["effect"] as StatusEffect
			_active_effects.remove_at(index)
			effect_removed.emit(effect.effect_id)


func apply_effect(effect: StatusEffect) -> bool:
	if not is_enabled or effect == null or not effect.is_valid():
		return false

	for entry: Dictionary in _active_effects:
		var active := entry["effect"] as StatusEffect
		if active.effect_id == effect.effect_id:
			entry["effect"] = effect
			entry["remaining"] = effect.duration
			effect_applied.emit(effect)
			return true

	_active_effects.append({
		"effect": effect,
		"remaining": effect.duration,
	})
	effect_applied.emit(effect)
	return true


func remove_effect(effect_id: StringName) -> bool:
	for index in range(_active_effects.size()):
		var effect := _active_effects[index]["effect"] as StatusEffect
		if effect.effect_id == effect_id:
			_active_effects.remove_at(index)
			effect_removed.emit(effect_id)
			return true

	return false


func clear_debuffs() -> int:
	var removed := 0
	for index in range(_active_effects.size() - 1, -1, -1):
		var effect := _active_effects[index]["effect"] as StatusEffect
		if effect.polarity == StatusEffect.Polarity.DEBUFF:
			_active_effects.remove_at(index)
			effect_removed.emit(effect.effect_id)
			removed += 1

	return removed


func has_buff() -> bool:
	return _has_polarity(StatusEffect.Polarity.BUFF)


func has_debuff() -> bool:
	return _has_polarity(StatusEffect.Polarity.DEBUFF)


func has_effect(effect_id: StringName) -> bool:
	for entry: Dictionary in _active_effects:
		var effect := entry["effect"] as StatusEffect
		if effect.effect_id == effect_id:
			return true

	return false


func get_remaining(effect_id: StringName) -> float:
	for entry: Dictionary in _active_effects:
		var effect := entry["effect"] as StatusEffect
		if effect.effect_id == effect_id:
			return float(entry["remaining"])

	return 0.0


func disable() -> void:
	_active_effects.clear()
	super.disable()


func _has_polarity(polarity: StatusEffect.Polarity) -> bool:
	for entry: Dictionary in _active_effects:
		var effect := entry["effect"] as StatusEffect
		if effect.polarity == polarity:
			return true

	return false
