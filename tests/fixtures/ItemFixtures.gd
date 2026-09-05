extends RefCounted


static func equippable(id: StringName, slot: ItemData.EquipSlot) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.equipment_profile = ItemEquipmentProfile.new()
	item.equipment_profile.allowed_slots = [slot]
	item.equipment_profile.stats = ItemStats.new()
	return item
