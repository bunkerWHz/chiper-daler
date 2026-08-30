extends Button
class_name InventoryDragButton

signal data_dropped(data: Dictionary)
signal drag_finished(successful: bool, pointer_position: Vector2)

const KIND_INVENTORY_ITEM: StringName = &"inventory_item"
const KIND_EQUIPPED_ITEM: StringName = &"equipped_item"
const KIND_QUICK_SLOT: StringName = &"quick_slot"

const TARGET_NONE: StringName = &""
const TARGET_INVENTORY: StringName = &"inventory"
const TARGET_EQUIPMENT: StringName = &"equipment"
const TARGET_QUICK_SLOT: StringName = &"quick_slot"
const DRAG_THRESHOLD := 6.0

var drag_payload: Dictionary = {}
var drop_target: StringName = TARGET_NONE
var target_equip_slot: int = ItemData.EquipSlot.NONE
var _drag_armed := false
var _drag_origin := Vector2.ZERO
var _drag_in_progress := false


func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_END or not _drag_in_progress:
		return
	_drag_in_progress = false
	var viewport := get_viewport()
	drag_finished.emit(
		viewport.gui_is_drag_successful(), viewport.get_mouse_position()
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_drag_armed = mouse_button.pressed and not drag_payload.is_empty()
			_drag_origin = mouse_button.position
		return
	if not _drag_armed or not event is InputEventMouseMotion:
		return
	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion.position.distance_to(_drag_origin) < DRAG_THRESHOLD:
		return
	_drag_armed = false
	_drag_in_progress = true
	force_drag(drag_payload.duplicate(true), _create_drag_preview())
	accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	_drag_armed = false
	_drag_in_progress = true
	set_drag_preview(_create_drag_preview())
	return drag_payload.duplicate(true)


func _create_drag_preview() -> Control:
	var preview := Label.new()
	preview.text = String(drag_payload.get("display_name", text))
	preview.modulate = Color(1.0, 1.0, 1.0, 0.9)
	return preview


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
				(kind == KIND_INVENTORY_ITEM or kind == KIND_EQUIPPED_ITEM)
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
