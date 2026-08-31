extends Resource
class_name ItemAmmunitionProfile

@export var ammunition_type: StringName


func is_valid() -> bool:
	return not ammunition_type.is_empty()
