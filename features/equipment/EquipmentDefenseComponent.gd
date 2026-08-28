extends DamageModifierComponent
class_name EquipmentDefenseComponent

@export_range(1.0, 10000.0, 1.0) var defense_scale: float = 100.0

var _equipment: EquipmentComponent


func on_initialize() -> void:
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	if _equipment == null or not _equipment.is_enabled or defense_scale <= 0.0:
		push_error("EquipmentDefenseComponent requires equipment and valid scale")
		disable()


func modify_damage(_hit: HitData, damage: float) -> float:
	if not is_enabled or damage <= 0.0:
		return damage
	var defense := _equipment.get_total_defense()
	if defense <= 0.0:
		return damage
	return damage * defense_scale / (defense_scale + defense)
