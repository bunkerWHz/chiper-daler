extends Component
class_name StatusEffectComponent

signal effect_applied(effect: StatusEffect)
signal effect_removed(effect_id: StringName)
signal effect_ticked(effect: StatusEffect, applied_damage: float)

@export var dot_resistances: DotResistances = DotResistances.new()

var _active_effects: Array[Dictionary] = []
var _health: HealthComponent
var _revision: int = 0


func on_initialize() -> void:
	_health = actor.get_component(HealthComponent) as HealthComponent
	if _health != null and not _health.died.is_connected(clear_effects):
		_health.died.connect(clear_effects)


func _process(delta: float) -> void:
	if not is_enabled or not is_finite(delta) or delta <= 0.0:
		return
	# Signal handlers can remove, refresh or clear effects (including on death).
	for entry: Dictionary in _active_effects.duplicate():
		if not _active_effects.has(entry):
			continue
		var effect := entry["effect"] as StatusEffect
		var elapsed := minf(delta, float(entry["remaining"]))
		entry["remaining"] = maxf(float(entry["remaining"]) - delta, 0.0)
		if effect.damage_per_tick > 0.0:
			entry["tick_elapsed"] += elapsed
			while float(entry["tick_elapsed"]) + 0.0000001 >= effect.tick_interval:
				if not is_enabled or not _active_effects.has(entry):
					break
				if _health == null or not _health.is_enabled or _health.is_dead():
					remove_effect(effect.effect_id)
					break
				entry["tick_elapsed"] = maxf(float(entry["tick_elapsed"]) - effect.tick_interval, 0.0)
				var damage := effect.damage_per_tick
				if dot_resistances != null:
					damage = dot_resistances.reduce_damage(effect.effect_id, damage)
				var applied := _health.take_damage(damage)
				effect_ticked.emit(effect, applied)
		if _active_effects.has(entry) and float(entry["remaining"]) == 0.0:
			remove_effect(effect.effect_id)


func apply_effect(effect: StatusEffect) -> bool:
	if not is_enabled or effect == null or not effect.is_valid():
		return false
	if _health != null and _health.is_dead():
		return false
	if effect.damage_per_tick > 0.0 and (_health == null or not _health.is_enabled):
		return false

	var tick_elapsed := 0.0
	for index in range(_active_effects.size()):
		var entry := _active_effects[index]
		var active := entry["effect"] as StatusEffect
		if active.effect_id == effect.effect_id:
			# A weaker DOT must not replace, extend or postpone the stronger one.
			if effect.damage_per_tick < active.damage_per_tick:
				return false
			# A stronger DOT starts fresh; equal strength preserves the next tick.
			if effect.damage_per_tick == active.damage_per_tick and active.tick_interval == effect.tick_interval:
				tick_elapsed = float(entry["tick_elapsed"])
			_active_effects.remove_at(index)
			break

	_revision += 1
	_active_effects.append({
		"effect": effect.duplicate(true),
		"remaining": effect.duration,
		"tick_elapsed": tick_elapsed,
		"revision": _revision,
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
	for entry: Dictionary in _active_effects.duplicate():
		var effect := entry["effect"] as StatusEffect
		if effect.polarity == StatusEffect.Polarity.DEBUFF and _active_effects.has(entry):
			remove_effect(effect.effect_id)
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
	super.disable()
	clear_effects()


func clear_effects() -> void:
	var removed := _active_effects.duplicate()
	_active_effects.clear()
	for entry: Dictionary in removed:
		effect_removed.emit((entry["effect"] as StatusEffect).effect_id)


func _has_polarity(polarity: StatusEffect.Polarity) -> bool:
	for entry: Dictionary in _active_effects:
		var effect := entry["effect"] as StatusEffect
		if effect.polarity == polarity:
			return true

	return false
