extends Button
class_name InventoryDragButton

signal data_dropped(data: Dictionary)

const KIND_INVENTORY_ITEM: StringName = &"inventory_item"
const KIND_EQUIPPED_ITEM: StringName = &"equipped_item"
const KIND_QUICK_SLOT: StringName = &"quick_slot"

const TARGET_NONE: StringName = &""
const TARGET_INVENTORY: StringName = &"inventory"
const TARGET_EQUIPMENT: StringName = &"equipment"
const TARGET_QUICK_SLOT: StringName = &"quick_slot"

var drag_payload: Dictionary = {}
var drop_target: StringName = TARGET_NONE
var target_equip_slot: int = ItemData.EquipSlot.NONE


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	var preview := Label.new()
	preview.text = String(drag_payload.get("display_name", text))
	preview.modulate = Color(1.0, 1.0, 1.0, 0.9)
	set_drag_preview(preview)
	return drag_payload.duplicate(true)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var payload := data as Dictionary
	var kind := StringName(payload.get("kind", &""))
	match drop_target:
		TARGET_INVENTORY:
			return kind == KIND_EQUIPPED_ITEM or kind == KIND_QUICK_SLOT
		TARGET_EQUIPMENT:
			return (
				kind == KIND_INVENTORY_ITEM
				and int(payload.get("equip_slot", ItemData.EquipSlot.NONE))
				== target_equip_slot
			)
		TARGET_QUICK_SLOT:
			return (
				(kind == KIND_INVENTORY_ITEM and bool(payload.get("usable", false)))
				or kind == KIND_QUICK_SLOT
			)
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary:
		data_dropped.emit(data as Dictionary)
