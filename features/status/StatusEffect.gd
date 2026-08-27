extends Resource
class_name StatusEffect

enum Polarity { BUFF, DEBUFF }

@export var effect_id: StringName
@export var polarity: Polarity = Polarity.BUFF
@export_range(0.05, 3600.0, 0.05) var duration: float = 5.0


func is_valid() -> bool:
	return not effect_id.is_empty() and duration > 0.0
