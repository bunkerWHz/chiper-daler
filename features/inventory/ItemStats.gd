extends Resource
class_name ItemStats

@export_range(0.0, 100000.0, 0.1) var damage: float = 0.0
@export_range(0.0, 100000.0, 0.1) var defense: float = 0.0
@export_range(0.0, 100000.0, 0.1) var magic_defense: float = 0.0
@export_group("Regeneration per one-second tick")
@export_range(0.0, 10000.0, 0.1) var health_regeneration: float = 0.0
@export_range(0.0, 10000.0, 0.1) var mana_regeneration: float = 0.0
@export_range(0.0, 10000.0, 0.1) var stamina_regeneration: float = 0.0
@export var buff_type: StringName
@export var buff_value: float = 0.0
