extends Resource
class_name ItemEquipmentProfile

enum DisplaySlot {
	SAME_AS_EQUIPMENT,
	MAIN_HAND,
	OFF_HAND,
}

@export var allowed_slots: Array[ItemData.EquipSlot] = []
@export var stats: ItemStats
## Visual attachment only; does not change inventory slots or combat behavior.
@export var display_slot: DisplaySlot = DisplaySlot.SAME_AS_EQUIPMENT


func get_display_slot(equipment_slot: ItemData.EquipSlot) -> ItemData.EquipSlot:
	match display_slot:
		DisplaySlot.MAIN_HAND:
			return ItemData.EquipSlot.MAIN_HAND
		DisplaySlot.OFF_HAND:
			return ItemData.EquipSlot.OFF_HAND
	return equipment_slot


func can_equip_in(slot: ItemData.EquipSlot) -> bool:
	return slot != ItemData.EquipSlot.NONE and slot in allowed_slots


func get_primary_slot() -> ItemData.EquipSlot:
	return (
		allowed_slots.front()
		if not allowed_slots.is_empty()
		else ItemData.EquipSlot.NONE
	)
