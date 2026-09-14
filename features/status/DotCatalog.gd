@tool
extends Resource
class_name DotCatalog

## Explicit resource references also keep DOT definitions available in exported games.
@export var effects: Array[StatusEffect] = []:
	set(value):
		effects = value
		emit_changed()


func get_effect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for effect: StatusEffect in effects:
		if is_dot_definition(effect):
			if effect.effect_id not in ids:
				ids.append(effect.effect_id)
	ids.sort()
	return ids


func contains(effect_id: StringName) -> bool:
	return effect_id in get_effect_ids()


func register_effect(effect: StatusEffect) -> bool:
	if not is_dot_definition(effect):
		return false
	if contains(effect.effect_id):
		return false
	effects.append(effect)
	emit_changed()
	return true


## Read exported data: existing non-tool resources can be placeholders in the editor.
static func is_dot_definition(effect: StatusEffect) -> bool:
	return (
		effect != null and not effect.effect_id.is_empty()
		and is_finite(effect.duration) and effect.duration > 0.0
		and is_finite(effect.damage_per_tick) and effect.damage_per_tick > 0.0
		and is_finite(effect.tick_interval) and effect.tick_interval >= 0.05
	)
