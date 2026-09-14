extends Component
class_name EquipmentSwapComponent

signal swap_started(target_set: int, duration: float)
signal swap_finished(target_set: int, completed: bool)

@export_range(0.05, 30.0, 0.05) var base_duration: float = 2.0

var _equipment: EquipmentComponent
var _body: CharacterBodyComponent
var _input: InputComponent
var _attributes: CharacterAttributesComponent
var _health: HealthComponent
var _hit_stun: HitStunComponent
var _target_set: int = -1
var _starting_set: int = -1
var _duration: float = 0.0
var _remaining: float = 0.0


func on_initialize() -> void:
	_equipment = actor.get_component(EquipmentComponent) as EquipmentComponent
	_body = actor.get_component(CharacterBodyComponent) as CharacterBodyComponent
	_input = actor.get_component(InputComponent) as InputComponent
	_attributes = actor.get_component(CharacterAttributesComponent) as CharacterAttributesComponent
	_health = actor.get_component(HealthComponent) as HealthComponent
	_hit_stun = actor.get_component(HitStunComponent) as HitStunComponent
	if _equipment == null or _body == null or not _equipment.is_enabled or not _body.is_enabled:
		push_error("EquipmentSwapComponent requires enabled equipment and character body")
		disable()
		return
	if _hit_stun != null and not _hit_stun.hit_stun_started.is_connected(cancel_swap):
		_hit_stun.hit_stun_started.connect(cancel_swap)
	if _health != null and not _health.died.is_connected(cancel_swap):
		_health.died.connect(cancel_swap)


func request_swap(set_index: int) -> bool:
	if not can_swap() or set_index < 0 or set_index >= EquipmentComponent.WEAPON_SET_COUNT:
		return false
	if set_index == _equipment.get_active_weapon_set():
		return false
	_duration = get_swap_duration()
	_remaining = _duration
	_target_set = set_index
	_starting_set = _equipment.get_active_weapon_set()
	swap_started.emit(set_index, _duration)
	return true


func request_cycle() -> bool:
	if _equipment == null:
		return false
	return request_swap((_equipment.get_active_weapon_set() + 1) % EquipmentComponent.WEAPON_SET_COUNT)


func can_swap() -> bool:
	return (
		is_enabled and not is_swapping() and _can_stand()
		and (_input == null or not _input.is_enabled or is_zero_approx(_input.get_move_axis()))
		and not ExclusiveBehaviorGate.is_blocked(actor, self)
		and is_finite(base_duration) and base_duration > 0.0
	)


func _can_stand() -> bool:
	return (
		_equipment != null and _equipment.is_enabled
		and _body != null and _body.is_enabled and _body.is_on_floor()
		and is_zero_approx(_body.get_velocity().x)
		and (_health == null or _health.is_alive())
		and (_hit_stun == null or not _hit_stun.is_incapacitated())
	)


func get_swap_duration() -> float:
	var speed := _attributes.get_attack_speed_multiplier() if _attributes != null and _attributes.is_enabled else 1.0
	return base_duration / speed


func is_swapping() -> bool:
	return _target_set >= 0


func get_remaining() -> float:
	return _remaining


func get_duration() -> float:
	return _duration


func get_progress() -> float:
	return clampf(1.0 - _remaining / _duration, 0.0, 1.0) if is_swapping() and _duration > 0.0 else 0.0


func is_exclusive_behavior_active() -> bool:
	return is_swapping()


func get_locomotion_blocks() -> int:
	if not is_swapping():
		return LocomotionConstraint.Block.NONE
	return LocomotionConstraint.Block.HORIZONTAL | LocomotionConstraint.Block.JUMP | LocomotionConstraint.Block.DODGE


func _process(delta: float) -> void:
	if not is_enabled or not is_swapping() or delta <= 0.0 or not is_finite(delta):
		return
	if not _can_stand() or _equipment.get_active_weapon_set() != _starting_set:
		cancel_swap()
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining == 0.0:
		var target := _target_set
		_target_set = -1
		var completed := _equipment.switch_weapon_set(target)
		swap_finished.emit(target, completed)


func cancel_swap() -> void:
	if not is_swapping():
		return
	var target := _target_set
	_target_set = -1
	_remaining = 0.0
	swap_finished.emit(target, false)


func disable() -> void:
	super.disable()
	cancel_swap()


func _exit_tree() -> void:
	cancel_swap()
