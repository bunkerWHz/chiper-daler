extends Resource
class_name ItemStats

@export_range(0.0, 100000.0, 0.1) var damage: float = 0.0
@export_range(0.0, 100000.0, 0.1) var defense: float = 0.0
@export var buff_type: StringName
@export var buff_value: float = 0.0
@export_range(0, 999, 1) var strength_requirement: int = 0
@export_range(0, 999, 1) var dexterity_requirement: int = 0
