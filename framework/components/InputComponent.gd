extends Component
class_name InputComponent

const INPUT_PROCESS_PRIORITY := -100
const MOVE_LEFT_ACTION: StringName = &"move_left"
const MOVE_RIGHT_ACTION: StringName = &"move_right"
const MOVE_UP_ACTION: StringName = &"move_up"
const MOVE_DOWN_ACTION: StringName = &"move_down"
const JUMP_ACTION: StringName = &"jump"
const INTERACT_ACTION: StringName = &"interact"
const ATTACK_ACTION: StringName = &"attack"
const GUARD_ACTION: StringName = &"guard"
const DODGE_ACTION: StringName = &"dodge"
const EQUIPMENT_ACTIONS: Array[StringName] = [
	&"equip_melee",
	&"equip_item",
	&"equip_throwable",
	&"equip_bow",
	&"equip_crossbow",
	&"equip_magic",
	&"quick_slot_7",
	&"quick_slot_8",
]

var _move_axis: float = 0.0
var _vertical_axis: float = 0.0
var _jump_pressed: bool = false
var _jump_released: bool = false
var _interact_pressed: bool = false
var _attack_just_pressed: bool = false
var _attack_pressed: bool = false
var _attack_released: bool = false
var _guard_pressed: bool = false
var _guard_just_pressed: bool = false
var _dodge_pressed: bool = false
var _equipment_slot_request: int = -1


func _ready() -> void:
	process_priority = INPUT_PROCESS_PRIORITY
	process_physics_priority = INPUT_PROCESS_PRIORITY


func get_move_axis() -> float:
	return _move_axis


func get_vertical_axis() -> float:
	return _vertical_axis


func consume_jump_pressed() -> bool:
	if not _jump_pressed:
		return false

	_jump_pressed = false
	return true


func is_jump_released() -> bool:
	return _jump_released


func consume_interact_pressed() -> bool:
	if not _interact_pressed:
		return false

	_interact_pressed = false
	return true


func consume_attack_pressed() -> bool:
	if not _attack_just_pressed:
		return false

	_attack_just_pressed = false
	return true


func is_attack_pressed() -> bool:
	return _attack_pressed


func consume_attack_released() -> bool:
	if not _attack_released:
		return false

	_attack_released = false
	return true


func is_guard_pressed() -> bool:
	return _guard_pressed


func consume_guard_just_pressed() -> bool:
	if not _guard_just_pressed:
		return false

	_guard_just_pressed = false
	return true


func consume_dodge_pressed() -> bool:
	if not _dodge_pressed:
		return false

	_dodge_pressed = false
	return true


func consume_equipment_slot_request() -> int:
	var request := _equipment_slot_request
	_equipment_slot_request = -1
	return request


func _process(_delta: float) -> void:
	_interact_pressed = Input.is_action_just_pressed(INTERACT_ACTION)
	_attack_just_pressed = Input.is_action_just_pressed(ATTACK_ACTION)
	_attack_pressed = Input.is_action_pressed(ATTACK_ACTION)
	_attack_released = Input.is_action_just_released(ATTACK_ACTION)
	_guard_pressed = Input.is_action_pressed(GUARD_ACTION)
	_guard_just_pressed = Input.is_action_just_pressed(GUARD_ACTION)

	for slot_index in EQUIPMENT_ACTIONS.size():
		if Input.is_action_just_pressed(EQUIPMENT_ACTIONS[slot_index]):
			_equipment_slot_request = slot_index
			break


func _physics_process(_delta: float) -> void:
	_move_axis = Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	_vertical_axis = Input.get_axis(MOVE_UP_ACTION, MOVE_DOWN_ACTION)
	_jump_released = Input.is_action_just_released(JUMP_ACTION)
	_dodge_pressed = Input.is_action_just_pressed(DODGE_ACTION)

	if Input.is_action_just_pressed(JUMP_ACTION):
		_jump_pressed = true
