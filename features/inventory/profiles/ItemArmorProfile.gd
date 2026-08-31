extends Resource
class_name ItemArmorProfile

enum ArmorClass {
	LIGHT,
	HEAVY,
	ROBE,
}

@export var armor_class: ArmorClass = ArmorClass.LIGHT
@export var set_id: StringName
@export_range(0.0, 1000.0, 0.1) var poise: float = 0.0
