extends Component
class_name EquipmentComponent

enum Slot {
	MELEE,
	ITEM,
	THROWABLE,
	BOW,
	CROSSBOW,
	MAGIC,
}

signal equipment_changed(previous_slot: Slot, current_slot: Slot)

const EQUIPMENT_PROCESS_PRIORITY := -90

@export var default_slot: Slot = Slot.MELEE

var _input_component: InputComponent
var _current_slot: Slot = Slot.MELEE


func on_initialize() -> void:
	_input_component = actor.get_component(InputComponent) as InputComponent

	if _input_component == null or not _input_component.is_enabled:
		push_error("EquipmentComponent requires an enabled InputComponent")
		disable()
		return

	_current_slot = default_slot


func _ready() -> void:
	process_priority = EQUIPMENT_PROCESS_PRIORITY


func _process(_delta: float) -> void:
	var requested_slot := _input_component.consume_equipment_slot_request()

	if requested_slot >= 0 and requested_slot < Slot.size():
		equip(requested_slot)


func equip(slot: Slot) -> bool:
	if not is_enabled or slot == _current_slot:
		return false

	var previous_slot := _current_slot
	_current_slot = slot
	equipment_changed.emit(previous_slot, _current_slot)
	return true


func get_current_slot() -> Slot:
	return _current_slot


func get_current_slot_name() -> String:
	return Slot.keys()[_current_slot].to_pascal_case()


func is_slot_active(slot: Slot) -> bool:
	return is_enabled and _current_slot == slot


func allows_melee_actions() -> bool:
	return is_slot_active(Slot.MELEE)


func capture_runtime_state() -> Variant:
	return _current_slot


func restore_runtime_state(state: Variant) -> void:
	var slot := int(state)
	if slot >= 0 and slot < Slot.size():
		equip(slot as Slot)
