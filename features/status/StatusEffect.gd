extends Resource
class_name StatusEffect

enum Polarity { BUFF, DEBUFF }

@export var effect_id: StringName
@export var display_name: String = ""
@export var polarity: Polarity = Polarity.BUFF
@export_range(0.05, 3600.0, 0.05) var duration: float = 5.0
@export_group("Damage over time")
## Zero keeps this a normal timed status without damage.
@export_range(0.0, 100000.0, 0.1) var damage_per_tick: float = 0.0
@export_range(0.05, 3600.0, 0.05) var tick_interval: float = 1.0


func is_valid() -> bool:
	return (
		not effect_id.is_empty() and is_finite(duration) and duration > 0.0
		and is_finite(damage_per_tick) and damage_per_tick >= 0.0
		and is_finite(tick_interval) and tick_interval >= 0.05
	)
