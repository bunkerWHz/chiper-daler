extends Component
class_name EquipmentInputComponent

## Translates player commands into equipment operations. Optional for scripted actors.
const EQUIPMENT_INPUT_PROCESS_PRIORITY := -90

var _input: InputComponent
var _equipment: EquipmentComponent


func on_initialize() -> void:
	_input = actor.get_component(InputComponent) as InputComponent
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	if _input == null or _equipment == null:
		push_error("EquipmentInputComponent requires InputComponent and EquipmentComponent")
		disable()


func _ready() -> void:
	process_priority = EQUIPMENT_INPUT_PROCESS_PRIORITY


func _process(_delta: float) -> void:
	if not is_enabled or not _input.is_enabled or not _equipment.is_enabled:
		return
	if _input.consume_weapon_set_swap_pressed():
		_equipment.cycle_weapon_set()
