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
const INVENTORY_ACTION: StringName = &"inventory"
const QUICK_SLOT_PREVIOUS_ACTION: StringName = &"quick_slot_previous"
const QUICK_SLOT_NEXT_ACTION: StringName = &"quick_slot_next"
const WEAPON_SET_SWAP_ACTION: StringName = &"weapon_set_swap"
const QUICK_SLOT_ACTIONS: Array[StringName] = [
	&"quick_slot_1",
	&"quick_slot_2",
	&"quick_slot_3",
	&"quick_slot_4",
	&"quick_slot_5",
	&"quick_slot_6",
	&"quick_slot_7",
	&"quick_slot_8",
]

var _move_axis: float = 0.0
var _vertical_axis: float = 0.0
var _jump_pressed: bool = false
var _jump_released: bool = false
var _interact_pressed: bool = false
var _interact_released: bool = false
var _attack_just_pressed: bool = false
var _attack_pressed: bool = false
var _attack_released: bool = false
var _guard_pressed: bool = false
var _guard_just_pressed: bool = false
var _dodge_pressed: bool = false
var _quick_slot_request: int = -1
var _quick_slot_cycle_request: int = 0
var _weapon_set_swap_pressed := false
var _inventory_pressed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func consume_interact_released() -> bool:
	if not _interact_released:
		return false

	_interact_released = false
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


func consume_quick_slot_request() -> int:
	var request := _quick_slot_request
	_quick_slot_request = -1
	return request


func consume_quick_slot_cycle_request() -> int:
	var request := _quick_slot_cycle_request
	_quick_slot_cycle_request = 0
	return request


func consume_weapon_set_swap_pressed() -> bool:
	if not _weapon_set_swap_pressed:
		return false
	_weapon_set_swap_pressed = false
	return true


func consume_inventory_pressed() -> bool:
	if not _inventory_pressed:
		return false
	_inventory_pressed = false
	return true


func _process(_delta: float) -> void:
	_inventory_pressed = Input.is_action_just_pressed(INVENTORY_ACTION)
	_interact_pressed = Input.is_action_just_pressed(INTERACT_ACTION)
	_interact_released = Input.is_action_just_released(INTERACT_ACTION)
	_attack_just_pressed = Input.is_action_just_pressed(ATTACK_ACTION)
	_attack_pressed = Input.is_action_pressed(ATTACK_ACTION)
	_attack_released = Input.is_action_just_released(ATTACK_ACTION)
	_guard_pressed = Input.is_action_pressed(GUARD_ACTION)
	_guard_just_pressed = Input.is_action_just_pressed(GUARD_ACTION)
	_weapon_set_swap_pressed = Input.is_action_just_pressed(
		WEAPON_SET_SWAP_ACTION
	)
	_quick_slot_cycle_request = 0
	if Input.is_action_just_pressed(QUICK_SLOT_PREVIOUS_ACTION):
		_quick_slot_cycle_request = -1
	elif Input.is_action_just_pressed(QUICK_SLOT_NEXT_ACTION):
		_quick_slot_cycle_request = 1

	for slot_index in QUICK_SLOT_ACTIONS.size():
		if Input.is_action_just_pressed(QUICK_SLOT_ACTIONS[slot_index]):
			_quick_slot_request = slot_index
			break


func _physics_process(_delta: float) -> void:
	_move_axis = Input.get_axis(MOVE_LEFT_ACTION, MOVE_RIGHT_ACTION)
	_vertical_axis = Input.get_axis(MOVE_UP_ACTION, MOVE_DOWN_ACTION)
	_jump_released = Input.is_action_just_released(JUMP_ACTION)
	_dodge_pressed = Input.is_action_just_pressed(DODGE_ACTION)

	if Input.is_action_just_pressed(JUMP_ACTION):
		_jump_pressed = true
