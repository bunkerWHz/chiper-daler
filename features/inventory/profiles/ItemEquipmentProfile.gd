extends Resource
class_name ItemEquipmentProfile

@export var allowed_slots: Array[ItemData.EquipSlot] = []
@export var stats: ItemStats


func can_equip_in(slot: ItemData.EquipSlot) -> bool:
	return slot != ItemData.EquipSlot.NONE and slot in allowed_slots


func get_primary_slot() -> ItemData.EquipSlot:
	return (
		allowed_slots.front()
		if not allowed_slots.is_empty()
		else ItemData.EquipSlot.NONE
	)
